import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter; // for subtle glass blur on control panel
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class _Location {
  final String id;
  final String name;
  final String type; // 'disposal' | 'mechanic'
  final LatLng position;
  final String? address;

  const _Location({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    this.address,
  });
}

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  LatLng? _myLocation;
  bool _locating = false;
  final _mapController = MapController();
  bool _showDisposal = true;
  bool _showMechanic = true;
  static const _davaoCenter = LatLng(7.1907, 125.4553);

  Future<void> _locateMe() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        setState(() => _locating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locating = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locating = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = latlng);
      _mapController.move(latlng, 15);
    } catch (_) {
      // best-effort: ignore
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors and theming shortcuts
    final scheme = Theme.of(context).colorScheme;
    final surfaceGlass = scheme.surface.withOpacity(0.75);

    // Sample locations across Davao (mechanic shops and disposal centers)
    const locations = <_Location>[
      _Location(
        id: 'loc1',
        name: 'Davao E-Waste Drop-off - Toril',
        type: 'disposal',
        position: LatLng(7.0152, 125.4973),
        address: 'Toril District, Davao City',
      ),
      _Location(
        id: 'loc2',
        name: 'Agdao Recycling Hub',
        type: 'disposal',
        position: LatLng(7.1020, 125.6240),
        address: 'Agdao, Davao City',
      ),
      _Location(
        id: 'loc3',
        name: 'Bajada Auto Electrical',
        type: 'mechanic',
        position: LatLng(7.0910, 125.6125),
        address: 'Bajada, Davao City',
      ),
      _Location(
        id: 'loc4',
        name: 'Matina Battery Center',
        type: 'mechanic',
        position: LatLng(7.0604, 125.5948),
        address: 'Matina Crossing, Davao City',
      ),
      _Location(
        id: 'loc5',
        name: 'Mintal Recovery Facility',
        type: 'disposal',
        position: LatLng(7.1051, 125.4550),
        address: 'Mintal, Davao City',
      ),
      _Location(
        id: 'loc6',
        name: 'Lanang Battery Shop',
        type: 'mechanic',
        position: LatLng(7.1174, 125.6495),
        address: 'Lanang, Davao City',
      ),
      _Location(
        id: 'loc7',
        name: 'Talomo E-Waste Center',
        type: 'disposal',
        position: LatLng(7.0519, 125.5593),
        address: 'Talomo, Davao City',
      ),
      _Location(
        id: 'loc8',
        name: 'Sasa Auto Electrical & Battery',
        type: 'mechanic',
        position: LatLng(7.1291, 125.6576),
        address: 'Sasa, Davao City',
      ),
      _Location(
        id: 'loc9',
        name: 'Buhangin Recycling Point',
        type: 'disposal',
        position: LatLng(7.1248, 125.6176),
        address: 'Buhangin, Davao City',
      ),
      _Location(
        id: 'loc10',
        name: 'Bangkerohan Auto Electrical',
        type: 'mechanic',
        position: LatLng(7.0738, 125.6157),
        address: 'Bangkerohan, Davao City',
      ),
    ];

    final filtered = locations.where((l) =>
        (l.type == 'disposal' && _showDisposal) ||
        (l.type == 'mechanic' && _showMechanic));
    final locationMarkers = filtered
        .map(
          (loc) => Marker(
            width: 40,
            height: 48,
            point: loc.position,
            child: GestureDetector(
              onTap: () => _showLocationSheet(context, loc),
              child: _MapPin(type: loc.type),
            ),
          ),
        )
        .toList();
    final myMarker = _myLocation == null
        ? const <Marker>[]
        : [
            Marker(
              width: 44,
              height: 44,
              point: _myLocation!,
              child: _MyLocationDot(),
            ),
          ];

    return Scaffold(
      appBar: AppBar(title: const Text('Davao E-Waste & Mechanics')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _davaoCenter,
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.iot_e_waste_monitor',
          ),
          MarkerLayer(markers: [...locationMarkers, ...myMarker]),
          // Top center filter chips (refined styling)
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: surfaceGlass,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilterChip(
                      showCheckmark: false,
                      label: Row(
                        children: const [
                          Icon(Icons.recycling, color: Colors.green, size: 18),
                          SizedBox(width: 6),
                          Text('Disposal'),
                        ],
                      ),
                      selected: _showDisposal,
                      onSelected: (v) => setState(() => _showDisposal = v),
                    ),
                    const SizedBox(width: 10),
                    FilterChip(
                      showCheckmark: false,
                      label: Row(
                        children: const [
                          Icon(Icons.build, color: Colors.orange, size: 18),
                          SizedBox(width: 6),
                          Text('Mechanic'),
                        ],
                      ),
                      selected: _showMechanic,
                      onSelected: (v) => setState(() => _showMechanic = v),
                    ),
                    // Right icon removed (redundant with bottom control bar)
                  ],
                ),
              ),
            ),
          ),
          // Bottom-center controls and attribution stacked
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Control bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: surfaceGlass,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CircleIconButton(
                                icon: Icons.my_location,
                                tooltip:
                                    _locating ? 'Locating…' : 'My location',
                                onPressed: _locating ? null : _locateMe,
                                isBusy: _locating,
                              ),
                              const SizedBox(width: 10),
                              _CircleIconButton(
                                icon: Icons.explore, // compass icon
                                tooltip: 'Align to North',
                                onPressed: () => _mapController.rotate(0),
                              ),
                              const SizedBox(width: 10),
                              _CircleIconButton(
                                icon: Icons.info_outline,
                                tooltip: 'Legend',
                                onPressed: () => _showLegend(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Attribution
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: surfaceGlass,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showLocationSheet(BuildContext context, _Location loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(loc.type == 'disposal' ? Icons.recycling : Icons.build,
                      color: loc.type == 'disposal'
                          ? Colors.green
                          : Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (loc.address != null) ...[
                Row(
                  children: [
                    const Icon(Icons.place, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(loc.address!)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.map, size: 18),
                  const SizedBox(width: 6),
                  Text(
                      'Lat: ${loc.position.latitude.toStringAsFixed(5)}, Lng: ${loc.position.longitude.toStringAsFixed(5)}'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openDirections(context, loc),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  static void _showLegend(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(
              leading: Icon(Icons.recycling, color: Colors.green),
              title: Text('Battery Disposal / E-Waste Center'),
            ),
            ListTile(
              leading: Icon(Icons.build, color: Colors.orange),
              title: Text('Mechanic / Auto Electrical Shop'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openDirections(
      BuildContext context, _Location loc) async {
    final messenger = ScaffoldMessenger.of(context);
    final lat = loc.position.latitude;
    final lng = loc.position.longitude;

    // 1) Try geo: scheme (opens any installed map app)
    final geoUri = Uri.parse(
        'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(loc.name)})');
    try {
      final launched =
          await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {/* ignore and fallback */}

    // 2) Fallback to OSM directions in browser
    final osmDir =
        Uri.parse('https://www.openstreetmap.org/directions?to=$lat,$lng');
    try {
      final launched =
          await launchUrl(osmDir, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {/* ignore and fallback */}

    // 3) Final fallback: OSM map centered with marker
    final osmView = Uri.parse(
        'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng');
    try {
      final launched =
          await launchUrl(osmView, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {/* ignore */}

    messenger.showSnackBar(const SnackBar(content: Text('Could not open map')));
  }
}

// --- UI helpers ---

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool isBusy;
  const _CircleIconButton({
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = isBusy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(icon, size: 22);
    final btn = Ink(
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        shape: const CircleBorder(),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: iconWidget,
        splashRadius: 24,
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _MapPin extends StatelessWidget {
  final String type; // 'disposal' | 'mechanic'
  const _MapPin({required this.type});

  @override
  Widget build(BuildContext context) {
    final isDisposal = type == 'disposal';
    final color = isDisposal ? Colors.green.shade600 : Colors.orange.shade600;
    final icon = isDisposal ? Icons.recycling : Icons.build;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        // Pointer
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.20),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
