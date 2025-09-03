// lib/screens/case_type_stats_screen.dart
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

  // dropdown lists for region/district/community
  List<String> _regions = [];
  List<String> _districts = [];
  List<String> _communities = [];

  final String _baseSummaryUrl =
      'https://health-case-tracker-backend-o82a.onrender.com/api/cases/type-summary';
  final String _baseRegionsUrl =
      'https://health-case-tracker-backend-o82a.onrender.com/api/facilities/regions';
  final String _baseDistrictsUrl =
      'https://health-case-tracker-backend-o82a.onrender.com/api/facilities/districts';
  final String _baseCommunitiesUrl =
      'https://health-case-tracker-backend-o82a.onrender.com/api/facilities/communities';

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
      await _loadRegions();
      await _loadCaseTypeOptions(); // populates _allTypes and _items initially
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
        // fallback empty
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
    });

    if (region == 'All') return;

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
    });

    if (region == 'All' || district == 'All') return;

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

  Color _statusDotColor(String label) {
    switch (label) {
      case 'Recovered':
        return Colors.green;
      case 'Ongoing treatment':
        return Colors.brown;
      case 'Deceased':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _legend() {
    const labels = ['Recovered', 'Ongoing treatment', 'Deceased'];
    return Wrap(
      spacing: 12,
      children: labels
          .map((label) => _LegendDot(
                color: _statusDotColor(label),
                label: label,
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Reported Case Types',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              // FILTER ROW
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // legend
                    _legend(),
                    const SizedBox(height: 12),
                    // dropdown row: Case Type | Region | District | Community
                    Row(
                      children: [
                        // Case type
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedCaseTypeId,
                            decoration: InputDecoration(
                              labelText: 'Case Type',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey[50],
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
                            ),
                            items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: (v) {
                              final sel = v ?? 'All';
                              setState(() {
                                _selectedRegion = sel;
                                // reset downstream
                                _selectedDistrict = 'All';
                                _selectedCommunity = 'All';
                                _districts = ['All'];
                                _communities = ['All'];
                              });
                              // load districts for region
                              if (sel != 'All') {
                                _loadDistricts(sel).then((_) => _applyFilters());
                              } else {
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
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
                            ),
                            items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (_selectedRegion == 'All')
                                ? null
                                : (v) {
                                    final sel = v ?? 'All';
                                    setState(() {
                                      _selectedDistrict = sel;
                                      _selectedCommunity = 'All';
                                      _communities = ['All'];
                                    });
                                    if (sel != 'All') {
                                      _loadCommunities(_selectedRegion, sel).then((_) => _applyFilters());
                                    } else {
                                      _applyFilters();
                                    }
                                  },
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
                            ),
                            items: _communities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (_selectedDistrict == 'All' || _selectedRegion == 'All')
                                ? null
                                : (v) {
                                    final sel = v ?? 'All';
                                    setState(() {
                                      _selectedCommunity = sel;
                                    });
                                    _applyFilters();
                                  },
                          ),
                        ),
                      ],
                    ),
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
        child: Center(child: Text('No entries', style: TextStyle(color: Colors.grey.shade600))),
      ));
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
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
