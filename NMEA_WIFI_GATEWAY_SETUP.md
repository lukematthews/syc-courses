# NMEA Wi-Fi Gateway Setup

The iPhone and Android apps support these NMEA 2000 Wi-Fi gateways:

- Actisense W2K-2
- Yacht Devices YDWG-02

Open **Instruments**, select the gateway, and enable boat data input, navigation output, or both. Selecting a gateway loads its factory network profile; the address, port, and protocol remain editable for installations with custom settings.

On iPhone, accept the local-network permission prompt the first time the app connects. The app prefers a fresh gateway position, course, speed, and heading fix when boat-data input is enabled, and falls back to iPhone GPS if the gateway data becomes stale.

## Actisense W2K-2

The default W2K-2 data-server profile used by the app is:

- IP address: `192.168.4.1`
- Protocol: TCP
- Port: `60001`
- Data protocol: NMEA 0183

Connect the iPhone to the W2K-2 Wi-Fi network, open **Instruments**, enable **Use for boat data input**, then tap **Connect**. Enable **Send output to instruments** only when the connected marine equipment is configured to receive navigation sentences.

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

Active Course and Quick Bearing output standard NMEA 0183 `BWC` and `RMB` waypoint sentences. Line Assist TTL and TTB remain on the iPhone because Garmin GNX race fields are not carried by a published standard NMEA 0183 sentence or standard NMEA 2000 PGN; arbitrary proprietary NMEA 0183 sentences are not converted into Garmin race data by the W2K-2.

When navigation output is connected, Quick Bearing and the Active Course race tracker show a True/Magnetic display switch. This changes only the bearing shown in the app; navigation calculations and transmitted true-bearing fields remain true-referenced.


See the [YDWG-02 user manual](https://www.yachtd.com/downloads/ydwg02.pdf) for Wi-Fi, NMEA Server, filtering, and security configuration. Change the gateway's factory Wi-Fi and administration passwords before normal use.
