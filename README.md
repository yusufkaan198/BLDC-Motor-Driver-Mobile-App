# BLDC Motor Driver - Mobile App

STM32F103 tabanlı sensörlü (Hall sensörlü) BLDC motor sürücü kartı için geliştirilmiş, HC-05 Bluetooth modülü üzerinden haberleşen Flutter mobil uygulaması. Motorun hız, akım ve durum telemetrisini gerçek zamanlı izlemeyi ve kontrol parametrelerini uzaktan ayarlamayı sağlar.

Özellikler
  - HC-05 üzerinden klasik Bluetooth (SPP) ile motor sürücü kartına bağlanma
  - Gerçek zamanlı motor telemetrisi (hız, akım, duty, sıcaklık)
  - Motor kontrol parametrelerinin (hız referansı) uygulama üzerinden ayarlanması

Donanım Tarafı:
  Bu uygulama şu depodaki BLDC motor sürücü donanım/firmware projesiyle birlikte çalışır:
  - STM32F103, trapezoidal komütasyon, Hall sensör geri beslemesi, PI hız/akım kontrolü, IR2110 gate driver, HC-05 Bluetooth modülü
  - Firmware repo: https://github.com/yusufkaan198/BLDC-Motor-Driver-Firmware
  - Kullanılan Teknolojiler
  - Flutter / Dart
  - local_packages/bluetooth_classic — özel Bluetooth Classic entegrasyonu
