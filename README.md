# Papiroska
CLI image viewer made on Zig
This app is educational experiment for myself, and it's goal is to use raw KGP to render images, and it's my first Zig project.
This app will only run as intended on terminals that support KGP and it wasn't designed for Windows.
Build deps: 
  Zig-0.14.1
  
Runtime deps:
  vips

Deps: 
  Zig-0.14.1
  vips

Building:
  ```zig build-exe papiroska.zig -O ReleaseSafe -target native-native -mcpu=native -static```
Usage:
papiroska {path-to-image}
