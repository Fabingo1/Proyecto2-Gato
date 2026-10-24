# Proyecto 2 - Gato (Tic-Tac-Toe) en ensamblador 8086

Juego de gato (tic-tac-toe) en modo texto, escrito en lenguaje ensamblador
8086 para el emulador **EMU8086**. El jugador (X) se enfrenta a la
computadora (O).

Proyecto 2 del curso **EIF205 Arquitectura de Computadoras**, Escuela de
Informática, Universidad Nacional (Costa Rica), 2026.

## Integrantes

| Nombre | Responsabilidad |
|---|---|
| Fabiano Arroyo | Macros, interfaz, retraso, comentarios, README |
| _(integrante 2)_ | Menú, pausa, vidas, Game Over y victoria, bitácora de pruebas |
| _(integrante 3)_ | Puntaje, High Score, marcador, alineación, informe técnico |

## Código original

Este proyecto parte del juego **TicTacToe** de shairaziz y colaboradores,
publicado en GitHub:

**https://github.com/shairaziz/TicTacToe**

Ese repositorio se usó como base, según lo permitido por el profesor, y
sobre él el grupo hizo las modificaciones que se listan más abajo. El
primer commit de este repositorio ("Archivo base") contiene el código
original sin cambios, para que se pueda comparar con la versión final.

## Requisitos

- **EMU8086** (Windows).
- Opcional: **DOSBox**, para correr el ejecutable fuera del emulador.

## Cómo compilar y ejecutar

### En EMU8086

1. Abrir EMU8086.
2. **File → Open** y elegir el archivo `.asm` del juego.
3. Presionar **emulate** (compila y abre el emulador).
4. En la ventana del emulador, presionar **run**.
5. Hacer clic en la ventana **emulator screen** para que reciba las teclas.

Si el juego va lento, poner **step delay** en 0 en la ventana del emulador.

### En DOSBox (opcional)

1. En EMU8086, presionar **compile** y guardar el ejecutable (`.exe`).
2. Abrir DOSBox y escribir (cambiando la ruta por la carpeta del ejecutable):

   ```
   mount c C:\ruta\de\la\carpeta
   c:
   nombre_del_archivo.exe
   ```

## Cómo jugar

| Tecla | Acción |
|---|---|
| `P` / `C` | Al inicio: elegir quién empieza (Jugador o Computadora) |
| `1` a `9` | Marcar la casilla con ese número |
| `Y` / `N` | Al terminar: jugar otra vez o salir |

Las casillas están numeradas así:

```
1 | 2 | 3
---------
4 | 5 | 6
---------
7 | 8 | 9
```

Gana quien complete primero una fila, una columna o una diagonal. Si se
llenan las 9 casillas sin ganador, es empate. Si se escoge una casilla
ocupada o una tecla que no sea del 1 al 9, el juego avisa y vuelve a pedir
la jugada.

## Cambios respecto al original

_(Se completa conforme se hagan los cambios.)_

- [x] Macros `IMPRIMIR` y `LIMPIAR_PANTALLA`.
- [x] Interfaz: borrar la pantalla y mostrar el tablero desde el inicio.
- [x] Retraso mientras la computadora "piensa".
- [ ] Menú principal y pausa.
- [ ] Vidas, Game Over y victoria de la partida.
- [ ] Puntaje acumulado y High Score.
- [ ] Marcador de más de un dígito.
- [ ] Alineación de las variables en memoria.
- [x] Comentarios del código en español.

## Estructura del repositorio

| Archivo | Contenido |
|---|---|
| `README.md` | Este documento |
| `Tic-tac-toe compact file.asm` | Código fuente del juego |
