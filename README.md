# Proyecto 2 - Gato (Tic-Tac-Toe) en ensamblador 8086

Juego de gato (tic-tac-toe) en modo texto a color, escrito en lenguaje
ensamblador 8086 para el emulador **EMU8086**. El jugador (X) se enfrenta a
la computadora (O) en una partida de varias rondas, con puntaje, vidas y
récord (High Score).

Proyecto 2 del curso **EIF205 Arquitectura de Computadoras**, Escuela de
Informática, Universidad Nacional (Costa Rica), 2026.

## Integrantes

| Nombre | Responsabilidad |
|---|---|
| Fabiano Arroyo | Macros, interfaz, retraso, comentarios, README |
| Lorenzo Aguilar | Menú, pausa, vidas, Game Over y victoria, bitácora de pruebas |
| _(integrante 3)_ | Puntaje, High Score, marcador, alineación, informe técnico |

## Código original

Este proyecto parte del juego **TicTacToe** de shairaziz y colaboradores,
publicado en GitHub:

**https://github.com/shairaziz/TicTacToe**

Ese repositorio se usó como base, según lo permitido por el profesor, y
sobre él el grupo hizo las modificaciones que se listan más abajo. El
commit "Archivo base" de este repositorio contiene el código original sin
cambios, para que se pueda comparar con la versión final.

## Requisitos

- **EMU8086** (Windows).
- Opcional: **DOSBox**, para correr el ejecutable fuera del emulador.

## Cómo compilar y ejecutar

### En EMU8086

1. Abrir EMU8086.
2. **File → Open** y elegir `Gato.asm`.
3. Presionar **emulate** (compila y abre el emulador).
4. En la ventana del emulador, presionar **run**.
5. Hacer clic en la ventana **emulator screen** para que reciba las teclas.

Si el juego va lento, poner **step delay** en 0 en la ventana del emulador.
Si se agranda o maximiza la ventana del emulador, el juego vuelve a poner
la pantalla en 80 x 25 y la redibuja.

### En DOSBox (opcional)

1. En EMU8086, presionar **compile** y guardar el ejecutable (`Gato.exe`).
2. Abrir DOSBox y escribir (cambiando la ruta por la carpeta del ejecutable):

   ```
   mount c C:\ruta\de\la\carpeta
   c:
   gato.exe
   ```

## Cómo jugar

### Reglas

Una **partida** está formada por varias **rondas** de gato. En cada ronda
gana quien complete primero una fila, una columna o una diagonal; si se
llenan las 9 casillas sin ganador, es empate.

| Resultado de la ronda | Efecto |
|---|---|
| Ganar | +100 puntos |
| Empatar | +25 puntos |
| Perder | −1 vida |

- Se empieza con **3 vidas** (corazones en la barra de estado).
- **VICTORIA:** llegar a **500 puntos**.
- **GAME OVER:** quedarse sin vidas.
- El **récord** (High Score) se guarda mientras el programa esté abierto y
  se muestra en el menú y en la barra de estado.

Si se escoge una casilla ocupada o una tecla que no sea del 1 al 9, el juego
suena, avisa y vuelve a pedir la jugada.

### Controles

| Pantalla | Tecla | Acción |
|---|---|---|
| Menú principal | `1` | Jugar |
| | `2` | Ver instrucciones |
| | `3` o `ESC` | Salir |
| Inicio de cada ronda | `J` / `C` | Elegir quién empieza (Jugador o Computadora) |
| Durante la ronda | `1` a `9` | Marcar la casilla con ese número |
| | `P` | Pausa |
| Pausa | `P` | Continuar la partida |
| | `M` | Volver al menú (se pierde la partida) |
| Victoria / Game Over | `R` | Jugar otra partida |
| | `M` | Volver al menú principal |

Las teclas de letras funcionan en mayúscula o minúscula. Las casillas están
numeradas así:

```
 1 | 2 | 3
---+---+---
 4 | 5 | 6
---+---+---
 7 | 8 | 9
```

### Ajustes

Al inicio de `Gato.asm` hay constantes que se pueden cambiar antes de
compilar:

| Constante | Valor | Significado |
|---|---|---|
| `VIDAS_INICIALES` | 3 | Vidas al empezar la partida |
| `PUNTOS_GANAR` | 100 | Puntos por ganar una ronda |
| `PUNTOS_EMPATE` | 25 | Puntos por empatar una ronda |
| `PUNTOS_META` | 500 | Puntos para la victoria |
| `RETRASO_CPU` | 50 | Pausa de la computadora, en centésimas de segundo |

Las instrucciones dentro del juego toman estos valores de las constantes, así
que se actualizan solas.

## Cambios respecto al original

- [x] Macros: `IMPRIMIR`, `IMPRIMIR_COLOR`, `IMPRIMIR_NUM`,
  `LIMPIAR_PANTALLA`, `POSICIONAR`, `LEER_TECLA`, `MAYUSCULA` y `SONIDO`.
- [x] Interfaz a color con barra de estado (puntos, vidas, récord, ronda y
  meta) y tablero fijo que se actualiza directo en la memoria de video.
- [x] Retraso mientras la computadora "piensa" (reloj del sistema, `INT 21h/2Ch`).
- [x] Menú principal, pantalla de instrucciones y pausa.
- [x] Vidas, Game Over y victoria de la partida, con reinicio sin cerrar el
  emulador.
- [x] Puntaje acumulado y High Score.
- [x] Marcador de varios dígitos (números de 0 a 65535).
- [x] Alineación de las variables de 16 bits en direcciones pares.
- [x] Computadora más lista: si no puede ganar ni bloquear, prefiere el
  centro, luego las esquinas y luego los lados.
- [x] Efectos de sonido (opcional en el enunciado).
- [x] Mensajes y comentarios del código en español.

## Estructura del repositorio

| Archivo | Contenido |
|---|---|
| `README.md` | Este documento |
| `Gato.asm` | Código fuente del juego |
