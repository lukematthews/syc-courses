# NMEA Wi-Fi Gateway Setup

SYC Courses supports these NMEA 2000 Wi-Fi gateways on iOS and Android:

- Actisense W2K-2
- Yacht Devices YDWG-02

Open **Instruments**, select the gateway, and enable boat data input, navigation output, or both. Selecting a gateway loads its factory network profile; the address, port, and protocol remain editable for installations with custom settings.

## Yacht Devices YDWG-02

The factory NMEA Server #1 profile is:

- IP address: `192.168.4.1`
- Protocol: TCP
- Port: `1456`
- Data protocol: NMEA 0183

For boat data input, the YDWG NMEA Server must transmit data to the app. For navigation output, its direction must accept data from the app (`Both` or `Receive Only`). Use `Both` when input and output are both enabled.

If the YDWG is in Wi-Fi Client mode, enter the IP address assigned to it by the boat's router instead of the factory access-point address.

The app reads position, course, speed, and heading from supported NMEA 0183 sentences, including `GLL` rapid-position data produced by the YDWG's NMEA 2000 conversion. Navigation output uses `BWC` and `RMB` waypoint sentences.

Only enable output after checking the gateway and connected instrument configuration. Navigation sentences placed on the NMEA 2000 network may be consumed by a connected autopilot or chartplotter.

See the [YDWG-02 user manual](https://www.yachtd.com/downloads/ydwg02.pdf) for Wi-Fi, NMEA Server, filtering, and security configuration. Change the gateway's factory Wi-Fi and administration passwords before normal use.
