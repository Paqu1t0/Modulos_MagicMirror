import lgpio as GPIO
import time
import subprocess
import os
import sys
import json

# --- Configurações Iniciais ---
TRIG = 23
ECHO = 24
DISTANCIA_LIMITE = 150.0 # 1.5 metros = 150 cm
PORTA_HDMI = "HDMI-A-1"  

# --- Truque para funcionar no Raspberry Pi 5 (Wayland) ---
my_env = os.environ.copy()
my_env["WAYLAND_DISPLAY"] = "wayland-0"
my_env["XDG_RUNTIME_DIR"] = "/run/user/1000" 

# --- Configuração do GPIO ---
h = GPIO.gpiochip_open(0)
GPIO.gpio_claim_output(h, TRIG)
GPIO.gpio_claim_input(h, ECHO)

ecra_ligado = True 

def get_distance():
    GPIO.gpio_write(h, TRIG, 0)
    time.sleep(0.05) 

    GPIO.gpio_write(h, TRIG, 1)
    time.sleep(0.00001)
    GPIO.gpio_write(h, TRIG, 0)

    pulse_start = time.time()
    timeout_start = time.time()
    
    while GPIO.gpio_read(h, ECHO) == 0:
        pulse_start = time.time()
        if pulse_start - timeout_start > 0.1:
            return -1 

    pulse_end = time.time()
    while GPIO.gpio_read(h, ECHO) == 1:
        pulse_end = time.time()
        if pulse_end - pulse_start > 0.1:
            return -1 

    pulse_duration = pulse_end - pulse_start
    distance = pulse_duration * 17150
    return round(distance, 2)

def ligar_ecra():
    global ecra_ligado
    if not ecra_ligado:
        subprocess.run(["wlr-randr", "--output", PORTA_HDMI, "--on"], env=my_env, stderr=subprocess.DEVNULL)
        ecra_ligado = True

def desligar_ecra():
    global ecra_ligado
    if ecra_ligado:
        subprocess.run(["wlr-randr", "--output", PORTA_HDMI, "--off"], env=my_env, stderr=subprocess.DEVNULL)
        ecra_ligado = False

# --- Lógica Principal ---
if __name__ == '__main__':
    TEMPO_PARA_DESLIGAR = 5 
    
    GPIO.gpio_write(h, TRIG, 0)
    time.sleep(2) 
    
    ultimo_avistamento = time.time() 
    
    try:
        while True:
            dist = get_distance()
            agora = time.time()
            estado = ""
            
            # 1. ESTADO: PESSOA DETETADA
            # O teu script original ignora valores abaixo de 2.0 cm para evitar falsos positivos
            if dist != -1 and dist > 2.0 and dist < DISTANCIA_LIMITE:
                ultimo_avistamento = agora
                ligar_ecra()
                estado = "Pessoa detetada! A ler..."
                
            # 2. ESTADO: NINGUÉM DETETADO
            else:
                tempo_sem_ninguem = agora - ultimo_avistamento
                
                if tempo_sem_ninguem <= TEMPO_PARA_DESLIGAR:
                    tempo_restante = int(TEMPO_PARA_DESLIGAR - tempo_sem_ninguem)
                    estado = f"Sem ninguém. Desliga em {tempo_restante}s..."
                else:
                    desligar_ecra()
                    estado = "Poupança de energia (Ecrã Desligado)"
            
            # Formata os dados para o MagicMirror ler
            dist_formatada = dist if dist != -1 else 0
            dados = {
                "distancia": dist_formatada,
                "estado": estado
            }
            
            # Imprime em JSON (o node_helper.js apanha isto)
            print(json.dumps(dados), flush=True)
            
            # O truque da velocidade: lê a cada 0.3s!
            time.sleep(0.3)

    except KeyboardInterrupt:
        if not ecra_ligado:
            subprocess.run(["wlr-randr", "--output", PORTA_HDMI, "--on"], env=my_env)
        GPIO.gpiochip_close(h)
        sys.exit(0)