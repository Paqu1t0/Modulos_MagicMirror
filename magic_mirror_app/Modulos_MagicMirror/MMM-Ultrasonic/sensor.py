import lgpio as GPIO
import time
import subprocess
import os
import sys
import json

# --- Configurações Iniciais (fallback se config.json não existir) ---
TRIG = 23
ECHO = 24
PORTA_HDMI = "HDMI-A-1"

CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'config.json')

# Valores por defeito
distancia_limite = 150.0  # cm
tempo_para_desligar = 30  # segundos

# --- Função para carregar/recarregar config.json ---
def carregar_config():
    global distancia_limite, tempo_para_desligar
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                config_data = json.load(f)
                nova_distancia = float(config_data.get('DISTANCIA_LIMITE', distancia_limite))
                novo_tempo = int(config_data.get('TEMPO_PARA_DESLIGAR', tempo_para_desligar))
                # Só atualiza e imprime mensagem se os valores mudaram
                if nova_distancia != distancia_limite or novo_tempo != tempo_para_desligar:
                    distancia_limite = nova_distancia
                    tempo_para_desligar = novo_tempo
                    sys.stderr.write(
                        f"[MMM-Ultrasonic] Config recarregada: "
                        f"limite={distancia_limite}cm, tempo={tempo_para_desligar}s\n"
                    )
                else:
                    distancia_limite = nova_distancia
                    tempo_para_desligar = novo_tempo
    except Exception as e:
        sys.stderr.write(f"[MMM-Ultrasonic] Erro ao carregar config.json: {e}\n")

# Carregar config no arranque
carregar_config()


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
    GPIO.gpio_write(h, TRIG, 0)
    time.sleep(2)

    ultimo_avistamento = time.time()

    # Contador para recarregar config a cada ~10 segundos (10s / 0.3s por iteração ≈ 33 iterações)
    ITERACOES_RELOAD = 33
    contador_reload = 0

    try:
        while True:
            # Recarregar config.json periodicamente (sem reiniciar o processo)
            contador_reload += 1
            if contador_reload >= ITERACOES_RELOAD:
                carregar_config()
                contador_reload = 0

            dist = get_distance()
            agora = time.time()
            estado = ""

            # 1. ESTADO: PESSOA DETETADA
            if dist != -1 and dist > 2.0 and dist < distancia_limite:
                ultimo_avistamento = agora
                ligar_ecra()
                estado = "Pessoa detetada! A ler..."

            # 2. ESTADO: NINGUÉM DETETADO
            else:
                tempo_sem_ninguem = agora - ultimo_avistamento

                if tempo_sem_ninguem <= tempo_para_desligar:
                    tempo_restante = int(tempo_para_desligar - tempo_sem_ninguem)
                    estado = f"Sem ninguém. Desliga em {tempo_restante}s..."
                else:
                    desligar_ecra()
                    estado = "Poupança de energia (Ecrã Desligado)"

            # Formata os dados para o MagicMirror ler
            dist_formatada = dist if dist != -1 else 0
            dados = {
                "distancia": dist_formatada,
                "estado": estado,
                "limite": distancia_limite,
                "tempo": tempo_para_desligar
            }

            # Imprime em JSON (o node_helper.js apanha isto)
            print(json.dumps(dados), flush=True)

            # Lê a cada 0.3s
            time.sleep(0.3)

    except KeyboardInterrupt:
        if not ecra_ligado:
            subprocess.run(["wlr-randr", "--output", PORTA_HDMI, "--on"], env=my_env)
        GPIO.gpiochip_close(h)
        sys.exit(0)