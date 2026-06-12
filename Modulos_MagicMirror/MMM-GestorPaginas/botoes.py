import lgpio as GPIO
import time
import json
import sys

# Pinos onde ligaste os botões
BOTAO_PROX = 17
BOTAO_ANT = 27

# Configura o GPIO
h = GPIO.gpiochip_open(0)
GPIO.gpio_claim_input(h, BOTAO_PROX, GPIO.SET_PULL_UP)
GPIO.gpio_claim_input(h, BOTAO_ANT, GPIO.SET_PULL_UP)

# Prevenir duplo clique
ultimo_clique_prox = 0
ultimo_clique_ant = 0

try:
    print('Leitor de botões iniciado...', flush=True)
    while True:
        agora = time.time()
        
        # O botão lê 0 quando pressionado
        if GPIO.gpio_read(h, BOTAO_PROX) == 0:
            if agora - ultimo_clique_prox > 0.5:
                print(json.dumps({"acao": "proxima"}), flush=True)
                ultimo_clique_prox = agora
                
        if GPIO.gpio_read(h, BOTAO_ANT) == 0:
            if agora - ultimo_clique_ant > 0.5:
                print(json.dumps({"acao": "anterior"}), flush=True)
                ultimo_clique_ant = agora
                
        time.sleep(0.05) # Lê os botões 20x por segundo!

except KeyboardInterrupt:
    GPIO.gpiochip_close(h)
    sys.exit(0)