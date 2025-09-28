package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
	"unicode"
	"os/exec"
    "runtime"

	"golang.org/x/net/proxy"
	"golang.org/x/sys/windows/registry"
	"golang.org/x/sys/windows"
)

type ProxyConfig struct {
	Addr     string
	Port     int
	Username string
	Password string
}

type Settings struct {
	UseDefaultProxies bool `json:"use_default_proxies"`
	ServerPort        int  `json:"server_port"`
}

type HTTPHandler struct {
	socks5Dialer proxy.Dialer
	dialContext  func(ctx context.Context, network, addr string) (net.Conn, error)
}

func NewHTTPHandler(config ProxyConfig) (*HTTPHandler, error) {
	auth := &proxy.Auth{
		User:     config.Username,
		Password: config.Password,
	}
	dialer, err := proxy.SOCKS5("tcp", fmt.Sprintf("%s:%d", config.Addr, config.Port), auth, proxy.Direct)
	if err != nil {
		return nil, fmt.Errorf("failed to create SOCKS5 dialer: %w", err)
	}

	dialContext := func(ctx context.Context, network, addr string) (net.Conn, error) {
		return dialer.Dial(network, addr)
	}

	return &HTTPHandler{
		socks5Dialer: dialer,
		dialContext:  dialContext,
	}, nil
}

func (h *HTTPHandler) sendDecoyPacket(host string) {
	conn, err := h.socks5Dialer.Dial("tcp", "93.184.216.34:80")
	if err == nil {
		defer conn.Close()
		fakeData := []byte("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n")
		conn.Write(fakeData)
	}
}

type fragmentedConn struct {
	net.Conn
}

func (fc *fragmentedConn) Write(p []byte) (int, error) {
	chunkSize := 256
	total := 0
	for i := 0; i < len(p); i += chunkSize {
		end := i + chunkSize
		if end > len(p) {
			end = len(p)
		}
		n, err := fc.Conn.Write(p[i:end])
		total += n
		if err != nil {
			return total, err
		}
		time.Sleep(time.Millisecond * 10)
	}
	return total, nil
}

func mixCase(s string) string {
	runes := []rune(s)
	for i := range runes {
		if rand.Intn(2) == 0 {
			runes[i] = unicode.ToUpper(runes[i])
		} else {
			runes[i] = unicode.ToLower(runes[i])
		}
	}
	return string(runes)
}

func (h *HTTPHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodConnect {
		h.handleConnect(w, r)
	} else {
		h.handleHTTP(w, r)
	}
}

func (h *HTTPHandler) handleConnect(w http.ResponseWriter, r *http.Request) {
	hostPort := r.Host
	host, port, err := net.SplitHostPort(hostPort)
	if err != nil {
		hostPort = net.JoinHostPort(hostPort, "443")
		host, port = hostPort, "443"
	}

	destAddr := net.JoinHostPort(host, port)
	destConn, err := h.socks5Dialer.Dial("tcp", destAddr)
	if err != nil {
		http.Error(w, "Failed to connect to destination", http.StatusBadGateway)
		return
	}
	defer destConn.Close()

	w.WriteHeader(http.StatusOK)
	if hj, ok := w.(http.Hijacker); ok {
		clientConn, _, err := hj.Hijack()
		if err != nil {
			http.Error(w, "Failed to hijack connection", http.StatusInternalServerError)
			return
		}
	defer clientConn.Close()

		buf := make([]byte, 1024)
		n, err := clientConn.Read(buf)
		if err != nil {
			return
		}
		chunkSize := 256
		for i := 0; i < n; i += chunkSize {
			end := i + chunkSize
			if end > n {
				end = n
			}
			destConn.Write(buf[i:end])
			time.Sleep(time.Millisecond * 10)
		}

		go io.Copy(destConn, clientConn)
		io.Copy(clientConn, destConn)

		go h.sendDecoyPacket(host)
	} else {
		http.Error(w, "Hijacking not supported", http.StatusInternalServerError)
	}
}

func (h *HTTPHandler) handleHTTP(w http.ResponseWriter, r *http.Request) {
	hostVariations := []string{
		"host", "hosT", "hoSt", "hoST", "hOst", "hOsT", "hOSt", "hOST",
		"Host", "HosT", "HoSt", "HoST", "HOST", "HOst", "HOsT", "HOST",
	}
	randHost := hostVariations[rand.Intn(len(hostVariations))]
	mixedHost := mixCase(r.Host)
	r.Header.Set(randHost, mixedHost)

	transport := &http.Transport{
		DialContext: h.dialContext,
	}

	client := &http.Client{
		Transport: transport,
		Timeout:   30 * time.Second,
	}

	if r.Header.Get("Connection") == "keep-alive" {
		transport.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
			conn, err := h.dialContext(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			return &fragmentedConn{Conn: conn}, nil
		}
	}

	r.Header.Del("Proxy-Connection")
	r.RequestURI = ""
	resp, err := client.Do(r)
	if err != nil {
		http.Error(w, "Failed to forward request", http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	for k, v := range resp.Header {
		for _, vv := range v {
			w.Header().Add(k, vv)
		}
	}
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)

	go h.sendDecoyPacket(r.Host)
}

func loadSettings() Settings {
	file, err := os.Open("settings.json")
	if err != nil {
		return Settings{
			UseDefaultProxies: true,
			ServerPort:        8412,
		}
	}
	defer file.Close()

	var settings Settings
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&settings); err != nil {
		return Settings{
			UseDefaultProxies: true,
			ServerPort:        8412,
		}
	}

	if settings.ServerPort == 0 {
		settings.ServerPort = 8412
	}
	return settings
}

func loadProxies() []ProxyConfig {
	var configs []ProxyConfig
	if _, err := os.Stat("proxies.json"); err == nil {
		file, err := os.Open("proxies.json")
		if err != nil {
			return configs
		}
		defer file.Close()

		decoder := json.NewDecoder(file)
		if err := decoder.Decode(&configs); err != nil {
			return configs
		}
	}
	return configs
}

// Proxies removed from source for open source release - release binaries will include working proxies
func getDefaultProxies() []ProxyConfig {
	return []ProxyConfig{}
}

func getProxyConfig(settings Settings) ProxyConfig {
	var configs []ProxyConfig
	if settings.UseDefaultProxies {
		configs = getDefaultProxies()
	} else {
		configs = loadProxies()
		if len(configs) == 0 {
			configs = getDefaultProxies()
		}
	}

	maxAttempts := len(configs) * 2
	for attempt := 0; attempt < maxAttempts; attempt++ {
		r := rand.New(rand.NewSource(time.Now().UnixNano()))
		selected := configs[r.Intn(len(configs))]
		
		auth := &proxy.Auth{
			User:     selected.Username,
			Password: selected.Password,
		}
		_, err := proxy.SOCKS5("tcp", fmt.Sprintf("%s:%d", selected.Addr, selected.Port), auth, proxy.Direct)
		if err == nil {
			return selected
		}
	}

	return configs[0]
}

func notifyProxyChange() {
	wininet := windows.NewLazyDLL("wininet.dll")
	internetSetOption := wininet.NewProc("InternetSetOptionW")
	
	internetSetOption.Call(0, 39, 0, 0)
	internetSetOption.Call(0, 37, 0, 0)
}

func setSystemProxy(port int) error {
	key, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Internet Settings`, registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer key.Close()

	err = key.SetDWordValue("ProxyEnable", 1)
	if err != nil {
		return err
	}

	proxyServer := fmt.Sprintf("127.0.0.1:%d", port)
	err = key.SetStringValue("ProxyServer", proxyServer)
	if err != nil {
		return err
	}

	err = key.SetStringValue("ProxyOverride", "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>")
	if err != nil {
		return err
	}

	notifyProxyChange()

	return nil
}

func clearScreen() {
    switch runtime.GOOS {
    case "windows":
        cmd := exec.Command("cmd", "/c", "cls")
        cmd.Stdout = os.Stdout
        cmd.Run()
    default:
        fmt.Print("\033[2J\033[H")
    }
}

func clearSystemProxy() error {
    key, err := registry.OpenKey(registry.CURRENT_USER, `Software\Microsoft\Windows\CurrentVersion\Internet Settings`, registry.SET_VALUE)
    if err != nil {
        return err
    }
    defer key.Close()

    err = key.SetDWordValue("ProxyEnable", 0)
    if err != nil {
        return err
    }

    notifyProxyChange()

    return nil
}

func displayGUI(settings Settings) {
    clearScreen()

    fmt.Println(`
  _________.__.__   __                    __   
 /   _____/|__|  | |  | _________   _____/  |_ 
 \_____  \ |  |  | |  |/ /\_  __ \_/ __ \   __\
 /        \|  |  |_|    <  |  | \/\  ___/|  |  
/_______  /|__|____/__|_ \ |__|    \___  >__|  
        \/              \/             \/      
`)

    fmt.Println("Privacy as smooth as silk")
    fmt.Println("and as secret as it gets")
    fmt.Println()

    fmt.Println(strings.Repeat("=", 50))
    fmt.Printf("Proxy Active:     TRUE\n")
    fmt.Printf("Local Port:       %d\n", settings.ServerPort)
    fmt.Printf("Anti-DPI:         ENABLED\n")
    fmt.Printf("Fragmentation:    ENABLED\n")
    fmt.Printf("Decoy Packets:    ENABLED\n")
    fmt.Println(strings.Repeat("=", 50))
    fmt.Println("\nPress Ctrl+C to stop the proxy...")
    fmt.Println("\n" + strings.Repeat("-", 50))
}

type silentLogger struct{}

func (s silentLogger) Write(p []byte) (n int, err error) {
	return len(p), nil
}

func main() {
	log.SetOutput(&silentLogger{})
	
	settings := loadSettings()

	config := getProxyConfig(settings)

	err := setSystemProxy(settings.ServerPort)
	if err != nil {
	}

	displayGUI(settings)

	handler, err := NewHTTPHandler(config)
	if err != nil {
		os.Exit(1)
	}

	server := &http.Server{
		Addr:    fmt.Sprintf("127.0.0.1:%d", settings.ServerPort),
		Handler: handler,
	}

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			os.Exit(1)
		}
	}()

	<-sigChan
	fmt.Println("\nShutting down proxy gracefully...")
	
	clearSystemProxy()
	
	if err := server.Shutdown(context.Background()); err != nil {
	}
	fmt.Println("Proxy stopped")
}
