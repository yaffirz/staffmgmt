Put the two HID DigitalPersona installers in THIS folder before running the setup.
They are not shipped here (HID licensing); download them once from HID:

1) Reader driver — "DigitalPersona 4500 Non-WBF (Legacy) Driver"
   https://www.hidglobal.com/drivers/49061
   (Install the NON-WBF / Legacy one, NOT the WBF/Hello driver — the WBF driver
   hands the reader to Windows Hello and blocks the clock-in SDK.)

2) Local agent — "HID Authentication Device Client"
   From the HID DigitalPersona/TouchChip Developer Center / downloads.
   This is the service that listens on 127.0.0.1:52181 so the browser can reach
   the reader. (No HID developer licence is needed for the clock-in app itself.)

Drop both .exe/.msi files here, then run Install-ClockStation.bat from the parent
folder. The installer runs whatever installers it finds here (follow their
prompts). If you've already installed both on this PC, you can skip this and run
the setup with -SkipHid.

The folder may be left empty if the HID software is already installed.
