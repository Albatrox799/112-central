# CENTRAL 112 – CIUDAD REAL · Prototipo Fase 1

Este prototipo sirve para comprobar dos cosas antes de construir el juego completo:
1. Que funciona en tu Fire TV con fluidez.
2. Que el mando de PS4 responde bien.

## Qué puedes hacer en el prototipo

- Mover el mapa con el joystick izquierdo y acercar o alejar con L2/R2.
- A los pocos segundos entra una **llamada al 112** (un accidente). Elige qué decir y tranquiliza a la llamante para averiguar dónde está.
- Al colgar aparece el incidente en el mapa. Envía la **ambulancia A-01** y sigue cómo circula por las calles.
- Si cuelgas antes de tener la ubicación exacta, la ambulancia tendrá que buscar el lugar y tardará más.
- Al cabo de un minuto aparece un **aviso automático**: un coche a 112 km/h. Puedes enviar la **patrulla P-01**, mantener la vigilancia o no intervenir.
- Al terminar cada intervención verás un **informe con la valoración**.

El mapa es un **esquema de prueba**. Los nombres de las calles son provisionales; el plano basado en el Miguelturra real llega en la Fase 2.

## Controles

| Mando PS4 | Teclado (PC) | Acción |
|---|---|---|
| Joystick izquierdo | WASD / flechas | Mover el mapa |
| L2 / R2 | X / Z | Alejar / acercar |
| X | Enter | Seleccionar lo que hay en la mira / confirmar |
| Círculo | Esc | Volver / cerrar |
| Cuadrado | U | Lista de unidades |
| Triángulo | E | Lista de emergencias |
| Cruceta | Flechas | Elegir opciones |
| Options | P | Pausa (velocidad del tiempo, salir) |
| Share | F1 | Prueba de mando (muestra FPS y botones) |

---

## PASO 1 · Probarlo en el ordenador (Windows)

1. Descarga **Godot 4** (versión estándar, no la ".NET") de la web oficial: godotengine.org
2. Descomprime el archivo de Godot y ábrelo (no hay que instalarlo).
3. Descomprime la carpeta `CENTRAL_112` que te he pasado.
4. En Godot pulsa **Importar** y elige el archivo `project.godot` de esa carpeta.
5. Pulsa **F5** (o el botón ▶ de arriba a la derecha) para jugar.

Si aparece algún error en rojo en la parte de abajo, hazle una foto o cópialo y pásamelo.

## PASO 2 · Preparar la exportación a Android (solo la primera vez)

1. En Godot: menú **Editor → Gestionar plantillas de exportación → Descargar e instalar**.
2. Instala **Java 17** (por ejemplo "Eclipse Temurin JDK 17" desde adoptium.net).
3. Instala **Android Studio** (developer.android.com/studio). Ábrelo una vez y, en **SDK Manager**, comprueba que están instalados *Android SDK Platform-Tools*, *Android SDK Build-Tools* y *Android SDK Command-line Tools*.
4. En Godot: **Editor → Configuración del editor → Exportar → Android**. Rellena:
   - *Java SDK Path*: la carpeta de Java 17 (algo como `C:\Program Files\Eclipse Adoptium\jdk-17...`)
   - *Android SDK Path*: normalmente `C:\Users\TU_USUARIO\AppData\Local\Android\Sdk`
5. Las versiones recientes de Godot crean solas la clave de depuración. Si al exportar te pide un "keystore", avísame.

## PASO 3 · Crear el APK

1. Menú **Proyecto → Exportar**.
2. Ya está creado el perfil **"Fire TV (Android)"**. Selecciónalo.
3. Pulsa **Exportar proyecto**, marca **"Exportar con depuración"** y guárdalo como `central112.apk`.

El perfil incluye las arquitecturas de 32 bits (armeabi-v7a) y de 64 bits, así que debería servir para cualquier Fire TV Stick.

## PASO 4 · Preparar el Fire TV

1. **Configuración → Mi Fire TV → Acerca de** y pulsa 7 veces seguidas sobre el nombre del dispositivo. Aparecerá **Opciones para desarrolladores**.
2. En **Mi Fire TV → Opciones para desarrolladores** activa la **Depuración ADB** y las **aplicaciones de origen desconocido**.
3. En **Mi Fire TV → Acerca de → Red** apunta la **dirección IP** (por ejemplo 192.168.1.45).

(Los nombres de los menús pueden cambiar un poco según la versión.)

## PASO 5 · Instalar el APK en el Fire TV

El ordenador y el Fire TV tienen que estar en la misma wifi.

1. Abre la carpeta `platform-tools` del SDK de Android (dentro de la carpeta `Sdk` del paso 2).
2. Haz clic en la barra de direcciones de esa carpeta, escribe `cmd` y pulsa Enter.
3. Escribe (cambiando la IP por la tuya):
   ```
   adb connect 192.168.1.45:5555
   ```
4. En la tele saldrá un aviso: acepta la conexión.
5. Escribe (con la ruta donde guardaste el APK):
   ```
   adb install -r "C:\ruta\central112.apk"
   ```
6. Cuando ponga **Success**, el juego estará en **Tus aplicaciones** del Fire TV.

Otra opción sin comandos: sube el APK a Google Drive o Dropbox con un enlace directo y descárgalo en el Fire TV con la app **Downloader**.

## PASO 6 · Emparejar el mando de PS4

1. En el Fire TV: **Configuración → Mandos y dispositivos Bluetooth → Mandos de juegos → Añadir mandos de juegos**.
2. En el mando, mantén pulsados **Share + PS** hasta que la luz parpadee rápido.
3. Selecciona "Wireless Controller" en la tele.

## PASO 7 · Qué comprobar y qué contarme

- [ ] El juego se abre y se ve bien en la tele.
- [ ] Los textos se leen bien desde el sofá.
- [ ] El movimiento es fluido. Pulsa **Share** para ver los FPS: lo ideal es 30 o más.
- [ ] El joystick mueve el mapa y L2/R2 hacen zoom.
- [ ] X, Círculo, Cuadrado, Triángulo y Options hacen lo que pone en la tabla.
- [ ] Puedes contestar la llamada y elegir respuestas con la cruceta.
- [ ] La ambulancia va por las calles hasta el accidente.
- [ ] Aparece el aviso del coche rápido y la patrulla lo persigue.

**Si algún botón no responde o hace otra cosa:** pulsa Share (o actívalo desde Pausa → Prueba de mando), pulsa ese botón y dime el número que aparece en "Último". Con eso lo corrijo enseguida.

---

## Estructura del proyecto

```
CENTRAL_112/
├── project.godot              Configuración (720p, renderizador Compatibility)
├── export_presets.cfg         Perfil de exportación para Fire TV
├── scenes/main/main.tscn      Escena principal
├── scripts/
│   ├── autoload/controles.gd  Mando PS4 + teclado
│   ├── main/main.gd           Coordina todo el juego
│   ├── routing/red_viaria.gd  Calles y cálculo de rutas (A*)
│   ├── map/mapa_ciudad.gd     Dibujo del mapa
│   ├── vehicles/vehiculo.gd   Ambulancias, patrullas y sospechosos
│   ├── incidents/incidente.gd Emergencias en el mapa
│   ├── calls/llamada.gd       Motor de conversaciones
│   └── interface/hud.gd       Interfaz de televisión
└── data/
    ├── map/mapa_prueba.gd             Datos del mapa (editable)
    └── dialogues/llamada_accidente.gd Conversación de prueba (editable)
```

Las llamadas y el mapa son **datos aparte del código**: para añadir conversaciones nuevas no hay que reescribir el juego.
