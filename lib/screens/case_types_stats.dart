// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CaseTypeStatsScreen extends StatefulWidget {
  const CaseTypeStatsScreen({super.key});

  @override
  State<CaseTypeStatsScreen> createState() => _CaseTypeStatsScreenState();
}

class _CaseTypeStatsScreenState extends State<CaseTypeStatsScreen> {
  bool _loading = true;
  String? _error;

  // current displayed summaries (after filtering)
  List<CaseTypeSummary> _items = [];

  // all case types (used to populate Case Type dropdown - loaded initially)
  List<CaseTypeSummary> _allTypes = [];

  // filter selections (use 'All' sentinel for simplicity)
  String _selectedCaseTypeId = 'all';
  String _selectedRegion = 'All';
  String _selectedDistrict = 'All';
  String _selectedCommunity = 'All';
  String _selectedFacility = 'All'; // will hold facility _id when selected

  // dropdown lists for region/district/community/facility
  List<String> _regions = [];
  List<String> _districts = [];
  List<String> _communities = [];

  // facilities as id/name pairs shown in dropdown
  List<Map<String, String>> _facilities = [
    {'id': 'All', 'name': 'All'}
  ];

  // cached detailed facility list returned at initial load (id, name, region, district, subDistrict, community)
  List<Map<String, String>> _allFacilitiesDetailed = [];

  final String _baseSummaryUrl =
      'https://health-case-tracker-backend-o82a.onrender.com/api/cases/type-summary';
  final String _baseRegionsUrl =
      'https://health-case-tracker-backend-o82a.onrender.com/api/facilities/regions';
  final String _baseDistrictsUrl =
      'https://health-case-tracker-backend-o82a.onrender.com/api/facilities/districts';
  final String _baseCommunitiesUrl =
      'https://health-case-tracker-backend-o82a.onrender.com/api/facilities/communities';
  final String _baseFacilitiesUrl =
      'https://health-case-tracker-backend-o82a.onrender.com/api/facilities';

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load regions, case types and full facility list initially
      await _loadRegions();
      await _loadCaseTypeOptions(); // populates _allTypes and _items initially
      await _loadAllFacilities(); // load full facility list (cached)
    } catch (e) {
      setState(() {
        _error = 'Failed to load initial data';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<String> _token() async {
    return Provider.of<AuthProvider>(context, listen: false).user!.token;
  }

  // ------------------ helpers ------------------

  // Safely extract human name from API returned value (populated doc or string)
  String _extractName(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) {
      if (v['name'] != null) return v['name'].toString();
      // nested possibilities
      if (v['region'] is Map && v['region']['name'] != null) return v['region']['name'].toString();
      if (v['district'] is Map && v['district']['name'] != null) return v['district']['name'].toString();
      if (v['community'] is Map && v['community']['name'] != null) return v['community']['name'].toString();
      // fallback to any string-like field
      for (final val in v.values) {
        if (val is String && val.trim().isNotEmpty) return val.trim();
        if (val is Map && val['name'] is String && val['name'].trim().isNotEmpty) return val['name'].trim();
      }
      return '';
    }
    return v.toString();
  }

  // ------------------ loads ------------------

  // Load the initial list of case types from the summary endpoint (no filters)
  Future<void> _loadCaseTypeOptions() async {
    setState(() => _loading = true);
    try {
      final token = await _token();
      final uri = Uri.parse(_baseSummaryUrl);
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final List data = jsonDecode(resp.body);
      final items = data.map((e) => CaseTypeSummary.fromJson(e)).toList();
      setState(() {
        _allTypes = items;
        _items = items; // initial display shows all
      });
    } catch (e) {
      setState(() => _error = 'Failed to load case types');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRegions() async {
    try {
      final token = await _token();
      final resp = await http.get(Uri.parse(_baseRegionsUrl), headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        setState(() {
          _regions = ['All', ...data.map((e) => e.toString())];
        });
      } else {
        setState(() {
          _regions = ['All'];
        });
      }
    } catch (_) {
      setState(() => _regions = ['All']);
    }
  }

  Future<void> _loadDistricts(String region) async {
    setState(() {
      _districts = ['All'];
      _selectedDistrict = 'All';
      _communities = ['All'];
      _selectedCommunity = 'All';
      // keep _selectedFacility as-is; we'll refresh the facility list after districts are loaded
      _facilities = [
        {'id': 'All', 'name': 'All'}
      ];
    });

    if (region == 'All') {
      // resetting to full facilities (cached)
      await _loadFacilities(region: 'All', district: 'All', community: null);
      return;
    }

    try {
      final token = await _token();
      final uri = Uri.parse('$_baseDistrictsUrl?region=${Uri.encodeQueryComponent(region)}');
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        setState(() {
          _districts = ['All', ...data.map((e) => e.toString())];
        });
      } else {
        setState(() {
          _districts = ['All'];
        });
      }
    } catch (_) {
      setState(() {
        _districts = ['All'];
      });
    }
  }

  Future<void> _loadCommunities(String region, String district) async {
    setState(() {
      _communities = ['All'];
      _selectedCommunity = 'All';
      // keep _selectedFacility; we'll refresh facilities scoped to the district below
      _facilities = [
        {'id': 'All', 'name': 'All'}
      ];
    });

    if (region == 'All' || district == 'All') {
      // show full facilities
      await _loadFacilities(region: 'All', district: 'All', community: null);
      return;
    }

    try {
      final token = await _token();
      final uri = Uri.parse(
          '$_baseCommunitiesUrl?region=${Uri.encodeQueryComponent(region)}&district=${Uri.encodeQueryComponent(district)}');
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        setState(() {
          _communities = ['All', ...data.map((e) => e.toString())];
        });
      } else {
        setState(() {
          _communities = ['All'];
        });
      }
    } catch (_) {
      setState(() {
        _communities = ['All'];
      });
    }
  }

  // NEW: load full list of facilities (id + name + location fields) on initial load
  Future<void> _loadAllFacilities() async {
    setState(() {
      _facilities = [
        {'id': 'All', 'name': 'All'}
      ];
      _selectedFacility = 'All';
      _allFacilitiesDetailed = [];
    });

    try {
      final token = await _token();
      final resp = await http.get(Uri.parse(_baseFacilitiesUrl), headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        final items = data.map<Map<String, String>>((e) {
          if (e is Map) {
            final id = (e['_id'] ?? e['id'])?.toString() ?? '';
            final name = (e['name'] ?? e['facilityName'] ?? '').toString();
            final region = _extractName(e['region']);
            final district = _extractName(e['district']);
            final subDistrict = _extractName(e['subDistrict']);
            final community = _extractName(e['community']);
            return {
              'id': id,
              'name': name.isNotEmpty ? name : id,
              'region': region,
              'district': district,
              'subDistrict': subDistrict,
              'community': community,
            };
          } else {
            final s = e.toString();
            return {'id': s, 'name': s, 'region': '', 'district': '', 'subDistrict': '', 'community': ''};
          }
        }).toList();

        setState(() {
          _allFacilitiesDetailed = items;
          _facilities = [
            {'id': 'All', 'name': 'All'},
            ...items.map((i) => {'id': i['id']!, 'name': i['name']!})
          ];
        });
      } else {
        // keep default 'All' only
      }
    } catch (_) {
      // keep default
    }
  }

  /// Load facilities scoped to given region/district/community.
  /// If no region/district provided or both 'All', falls back to _allFacilitiesDetailed.
  Future<void> _loadFacilities({String? region, String? district, String? community}) async {
    // show temporary placeholder
    setState(() {
      _facilities = [
        {'id': 'All', 'name': 'All'}
      ];
    });

    // If we have the cached full list and the request is for "All", use it
    final wantsAll = (region == null || region == 'All') && (district == null || district == 'All');
    if (wantsAll && _allFacilitiesDetailed.isNotEmpty) {
      setState(() {
        _facilities = [
          {'id': 'All', 'name': 'All'},
          ..._allFacilitiesDetailed.map((i) => {'id': i['id']!, 'name': i['name']!})
        ];
      });
      final exists = _facilities.any((f) => f['id'] == _selectedFacility);
      if (!exists) {
        setState(() => _selectedFacility = 'All');
      }
      return;
    }

    // Otherwise call server with whatever scope provided
    try {
      final token = await _token();
      final params = <String, String>{};
      if (region != null && region != 'All') params['region'] = region;
      if (district != null && district != 'All') params['district'] = district;
      if (community != null && community != 'All') params['community'] = community;
      final uri = Uri.parse(_baseFacilitiesUrl).replace(queryParameters: params.isEmpty ? null : params);
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        final items = data.map<Map<String, String>>((e) {
          if (e is Map) {
            final id = (e['_id'] ?? e['id'])?.toString() ?? '';
            final name = (e['name'] ?? e['facilityName'] ?? '').toString();
            return {'id': id, 'name': name.isNotEmpty ? name : id};
          } else {
            final s = e.toString();
            return {'id': s, 'name': s};
          }
        }).toList();

        setState(() {
          _facilities = [
            {'id': 'All', 'name': 'All'},
            ...items
          ];
        });

        // Preserve selection if the selected facility is still present in the fetched list,
        // otherwise reset to 'All'
        final exists = _facilities.any((f) => f['id'] == _selectedFacility);
        if (!exists) {
          setState(() => _selectedFacility = 'All');
        }
      } else {
        // server error -> leave placeholder and clear selection
        setState(() => _selectedFacility = 'All');
      }
    } catch (_) {
      setState(() => _selectedFacility = 'All');
    }
  }

  // ------------------ apply filters ------------------

  // Apply current filters and reload summaries from backend
  Future<void> _applyFilters() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _token();
      final baseUri = Uri.parse(_baseSummaryUrl);

      final Map<String, String> params = {};

      if (_selectedCaseTypeId.isNotEmpty && _selectedCaseTypeId != 'all') {
        params['caseType'] = _selectedCaseTypeId;
      }
      if (_selectedRegion != 'All') {
        params['region'] = _selectedRegion;
      }
      if (_selectedDistrict != 'All') {
        params['district'] = _selectedDistrict;
      }
      if (_selectedCommunity != 'All') {
        params['community'] = _selectedCommunity;
      }
      // include facility filter if selected (we send facility id)
      if (_selectedFacility != 'All') {
        params['facility'] = _selectedFacility;
      }

      final uri = params.isNotEmpty ? baseUri.replace(queryParameters: params) : baseUri;
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final List data = jsonDecode(resp.body) as List;
      final items = data.map((e) => CaseTypeSummary.fromJson(e)).toList();
      setState(() {
        _items = items;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load summary';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildFilterRow() {
    // Single-row filter layout with five dropdowns.
    // Flexes chosen to give case type slightly more room.
    return Row(
      children: [
        // Case type
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: _selectedCaseTypeId,
            decoration: InputDecoration(
              labelText: 'Case Type',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.grey[50],
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All')),
              ..._allTypes.map((t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(t.name),
                  ))
            ],
            onChanged: (v) {
              setState(() {
                _selectedCaseTypeId = v ?? 'all';
              });
              _applyFilters();
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 8),

        // Region
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _selectedRegion,
            decoration: InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.grey[50],
              isDense: true,
            ),
            items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) async {
              final sel = v ?? 'All';
              setState(() {
                _selectedRegion = sel;
                // reset downstream selections but do NOT forcibly clear facility selection yet
                _selectedDistrict = 'All';
                _selectedCommunity = 'All';
                _districts = ['All'];
                _communities = ['All'];
              });
              // load districts for region and refresh facility list scoped to region
              if (sel != 'All') {
                await _loadDistricts(sel);
                await _loadFacilities(region: sel, district: null, community: null);
                await _applyFilters();
              } else {
                // region is All -> show full facilities
                await _loadFacilities(region: 'All', district: 'All', community: null);
                await _applyFilters();
              }
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 8),

        // District
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _selectedDistrict,
            decoration: InputDecoration(
              labelText: 'District',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.grey[50],
              isDense: true,
            ),
            items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (_selectedRegion == 'All')
                ? null
                : (v) async {
                    final sel = v ?? 'All';
                    setState(() {
                      _selectedDistrict = sel;
                      _selectedCommunity = 'All';
                      _communities = ['All'];
                      // do not clear _selectedFacility here; we will refresh facilities below and preserve if possible
                    });
                    if (sel != 'All') {
                      // load communities then refresh facilities under the district
                      await _loadCommunities(_selectedRegion, sel);
                      await _loadFacilities(region: _selectedRegion, district: sel, community: null);
                      await _applyFilters();
                    } else {
                      // district reset -> show facilities scoped to region (or full if region All)
                      await _loadFacilities(region: _selectedRegion, district: 'All', community: null);
                      await _applyFilters();
                    }
                  },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 8),

        // Community
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _selectedCommunity,
            decoration: InputDecoration(
              labelText: 'Community',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.grey[50],
              isDense: true,
            ),
            items: _communities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (_selectedDistrict == 'All' || _selectedRegion == 'All')
                ? null
                : (v) async {
                    final sel = v ?? 'All';
                    setState(() {
                      _selectedCommunity = sel;
                      // keep _selectedFacility; we'll refresh facilities for this community and preserve selection if present
                    });
                    if (sel != 'All') {
                      await _loadFacilities(region: _selectedRegion, district: _selectedDistrict, community: sel);
                      await _applyFilters();
                    } else {
                      await _loadFacilities(region: _selectedRegion, district: _selectedDistrict, community: null);
                      await _applyFilters();
                    }
                  },
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 8),

        // Facility (NEW) - enabled on load
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _facilities.any((f) => f['id'] == _selectedFacility) ? _selectedFacility : 'All',
            decoration: InputDecoration(
              labelText: 'Facility',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.grey[50],
              isDense: true,
            ),
            items: _facilities
                .map((f) => DropdownMenuItem(value: f['id'], child: Text(f['name'] ?? f['id'] ?? '')))
                .toList(),
            onChanged: (v) {
              final sel = v ?? 'All';
              setState(() {
                _selectedFacility = sel;
              });
              _applyFilters();
            },
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    final int totalReported = _items.fold<int>(0, (sum, it) => sum + it.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Case Types')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Title with total reported count shown beside it
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reported Case Types',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '($totalReported)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // FILTER CONTAINER (single-line filters)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // single-line filter row
                    _buildFilterRow(),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  ElevatedButton(onPressed: _initialLoad, child: const Text('Retry')),
                                ],
                              ),
                            )
                          : _items.isEmpty
                              ? const Center(child: Text('No case types found'))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: _items.length,
                                  itemBuilder: (_, i) => _CaseTypeTile(item: _items[i]),
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseTypeTile extends StatelessWidget {
  const _CaseTypeTile({required this.item});
  final CaseTypeSummary item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Total: ${item.total}'),
        childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        children: [
          _StatusBucketTile(
            label: 'Confirmed',
            color: Colors.red.shade700,
            count: item.confirmed.total,
            recovered: item.confirmed.recovered,
            ongoing: item.confirmed.ongoingTreatment,
            deceased: item.confirmed.deceased,
          ),
          const SizedBox(height: 6),
          _StatusBucketTile(
            label: 'Suspected',
            color: Colors.orange.shade700,
            count: item.suspected.total,
            recovered: item.suspected.recovered,
            ongoing: item.suspected.ongoingTreatment,
            deceased: item.suspected.deceased,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _StatusBucketTile extends StatelessWidget {
  const _StatusBucketTile({
    required this.label,
    required this.color,
    required this.count,
    required this.recovered,
    required this.ongoing,
    required this.deceased,
  });

  final String label;
  final Color color;
  final int count;
  final int recovered;
  final int ongoing;
  final int deceased;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (recovered > 0) {
      rows.add(_BreakdownRow(dotColor: Colors.green, label: 'Recovered', value: recovered));
    }
    if (ongoing > 0) {
      rows.add(_BreakdownRow(dotColor: Colors.brown, label: 'Ongoing treatment', value: ongoing));
    }
    if (deceased > 0) {
      rows.add(_BreakdownRow(dotColor: Colors.red, label: 'Deceased', value: deceased));
    }

    // If there are no rows (all zero), show a small helper row instead
    if (rows.isEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(child: Text('No entries', style: TextStyle(color: Colors.grey.shade600)))),

      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.grey.shade50,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(radius: 8, backgroundColor: color),
          title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          subtitle: Text('Total: $count'),
          childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          children: rows,
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.dotColor, required this.label, required this.value});

  final Color dotColor;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(radius: 6, backgroundColor: dotColor),
      title: Text('$label ($value)', style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

// ----- Models used locally in the screen -----
class CaseTypeSummary {
  final String id;
  final String name;
  final int total;
  final Breakdown confirmed;
  final Breakdown suspected;

  CaseTypeSummary({
    required this.id,
    required this.name,
    required this.total,
    required this.confirmed,
    required this.suspected,
  });

  factory CaseTypeSummary.fromJson(Map<String, dynamic> json) {
    return CaseTypeSummary(
      id: json['caseTypeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      total: (json['total'] ?? 0) as int,
      confirmed: Breakdown.fromJson((json['confirmed'] ?? {}) as Map<String, dynamic>),
      suspected: Breakdown.fromJson((json['suspected'] ?? {}) as Map<String, dynamic>),
    );
  }
}

class Breakdown {
  final int total;
  final int recovered;
  final int ongoingTreatment;
  final int deceased;

  Breakdown({
    required this.total,
    required this.recovered,
    required this.ongoingTreatment,
    required this.deceased,
  });

  factory Breakdown.fromJson(Map<String, dynamic> json) {
    return Breakdown(
      total: (json['total'] ?? 0) as int,
      recovered: (json['recovered'] ?? 0) as int,
      ongoingTreatment: (json['ongoingTreatment'] ?? 0) as int,
      deceased: (json['deceased'] ?? 0) as int,
    );
  }
}
