// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/all_cases_detail_bottom_view.dart';

class AllCasesScreen extends StatefulWidget {
  const AllCasesScreen({super.key});

  @override
  _AllCasesScreenState createState() => _AllCasesScreenState();
}

class _AllCasesScreenState extends State<AllCasesScreen> {
  List<dynamic> allCases = [];
  bool isLoading = true;

  String selectedFilter = 'All';
  List<String> filterOptions = ['All'];
  Set<String> regions = {};
  Set<String> districts = {};
  Set<String> communities = {};
  Set<String> subDistricts = {};

  @override
  void initState() {
    super.initState();
    fetchAllCases();
  }

  Future<void> fetchAllCases() async {
    setState(() => isLoading = true);
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    final base = 'https://health-case-tracker-backend-o82a.onrender.com/api/cases';

    // Prefer the dedicated endpoint that returns ALL cases to logged-in users
    final primaryUri = Uri.parse('$base/all-officers');
    final primaryResp = await http.get(primaryUri, headers: {'Authorization': 'Bearer $token'});

    if (primaryResp.statusCode == 200) {
      allCases = jsonDecode(primaryResp.body);
      _populateFilters();
      setState(() => isLoading = false);
      return;
    }

    // Backwards compatibility: try the older endpoints
    final rootResp = await http.get(Uri.parse(base), headers: {'Authorization': 'Bearer $token'});
    if (rootResp.statusCode == 200) {
      allCases = jsonDecode(rootResp.body);
      _populateFilters();
      setState(() => isLoading = false);
      return;
    }

    final myResp = await http.get(Uri.parse('$base/my-cases'), headers: {'Authorization': 'Bearer $token'});
    if (myResp.statusCode == 200) {
      allCases = jsonDecode(myResp.body);
      _populateFilters();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Showing your cases — server does not expose global cases endpoint.')),
      );
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load cases')));
  }

  // small helper to read either Map or String -> String

  /// Returns an effective location map for a case:
  /// { 'region', 'district', 'subDistrict', 'community' } (strings, may be empty)
  Map<String, String> _effectiveLocation(dynamic c) {
    String nameOf(dynamic v) {
      if (v == null) return '';
      if (v is Map) return (v['name'] ?? '').toString();
      return v.toString();
    }

    final result = {
      'region': '',
      'district': '',
      'subDistrict': '',
      'community': '',
    };

    // 1) Prefer server-synthesized case-level location (best)
    final caseLoc = c['location'];
    if (caseLoc != null && caseLoc is Map) {
      result['region'] = nameOf(caseLoc['region']);
      result['district'] = nameOf(caseLoc['district']);
      result['subDistrict'] = nameOf(caseLoc['subDistrict']);
      result['community'] = nameOf(caseLoc['community']);
      // if any is present, return early
      if (result.values.any((s) => s.isNotEmpty)) return result;
    }

    // 2) If the case's populated community exists and is different from facility's community,
    //    prefer that and try to use parent fields from the community if available
    final caseCommunity = c['community'];
    final hf = c['healthFacility'];
    String hfCommunityName = '';
    if (hf != null && hf is Map) {
      // facility may contain synthesized location already
      final hfLocation = hf['location'] ?? {};
      if (hfLocation is Map && hfLocation['community'] != null) {
        hfCommunityName = nameOf(hfLocation['community']);
      } else if (hf['community'] != null) {
        hfCommunityName = nameOf(hf['community']);
      }
    }

    final caseCommunityName = caseCommunity != null ? (caseCommunity is Map ? nameOf(caseCommunity['name'] ?? caseCommunity) : nameOf(caseCommunity)) : '';

    if (caseCommunityName.isNotEmpty && hfCommunityName.toLowerCase() != caseCommunityName.toLowerCase()) {
      // take names from community doc if present
      if (caseCommunity is Map) {
        result['community'] = nameOf(caseCommunity['name']);
        result['district'] = nameOf(caseCommunity['district']);
        result['subDistrict'] = nameOf(caseCommunity['subDistrict']);
        result['region'] = nameOf(caseCommunity['region']);
        return result;
      } else {
        result['community'] = caseCommunityName;
        return result;
      }
    }

    // 3) Fallback: use healthFacility's synthesized location
    final hfLocation = hf != null && hf is Map ? (hf['location'] ?? {}) : {};
    if (hfLocation is Map && hfLocation.isNotEmpty) {
      result['region'] = nameOf(hfLocation['region']);
      result['district'] = nameOf(hfLocation['district']);
      result['subDistrict'] = nameOf(hfLocation['subDistrict']);
      result['community'] = nameOf(hfLocation['community']);
      return result;
    }

    // 4) Last resort: top-level hf fields (could be populated objects)
    if (hf != null && hf is Map) {
      result['region'] = nameOf(hf['region']);
      result['district'] = nameOf(hf['district']);
      result['subDistrict'] = nameOf(hf['subDistrict']);
      result['community'] = nameOf(hf['community']);
    }

    return result;
  }

  void _populateFilters() {
    regions.clear();
    districts.clear();
    communities.clear();
    subDistricts.clear();

    for (final c in allCases) {
      final loc = _effectiveLocation(c);
      final r = loc['region'] ?? '';
      final d = loc['district'] ?? '';
      final sd = loc['subDistrict'] ?? '';
      final com = loc['community'] ?? '';

      if (r.isNotEmpty) regions.add(r);
      if (d.isNotEmpty) districts.add(d);
      if (sd.isNotEmpty) subDistricts.add(sd);
      if (com.isNotEmpty) communities.add(com);
    }

    filterOptions = [
      'All',
      'Suspected',
      'Confirmed',
      'Not a Case',
      'Ongoing Treatment',
      'Recovered',
      'Deceased',
      'Male',
      'Female',
      'Other',
      ...regions,
      ...districts,
      ...subDistricts,
      ...communities,
    ];
  }

  List<dynamic> getFilteredCases() {
    if (selectedFilter == 'All') return allCases;

    final f = selectedFilter.toLowerCase();
    return allCases.where((c) {
      final cs = (c['status'] ?? '').toString().toLowerCase();
      final ps = (c['patient']?['status'] ?? '').toString().toLowerCase();
      final g = (c['patient']?['gender'] ?? '').toString().toLowerCase();
      final loc = _effectiveLocation(c);
      final region = (loc['region'] ?? '').toString().toLowerCase();
      final district = (loc['district'] ?? '').toString().toLowerCase();
      final subDistrict = (loc['subDistrict'] ?? '').toString().toLowerCase();
      final community = (loc['community'] ?? '').toString().toLowerCase();

      return cs == f ||
          ps == f ||
          g == f ||
          region == f ||
          district == f ||
          subDistrict == f ||
          community == f;
    }).toList();
  }

  Widget caseSummaryCard(Map<String, dynamic> data) {
    final patient = data['patient'] ?? {};
    final caseType = ((data['caseType'] ?? {})['name'] ?? 'UNKNOWN').toString().toUpperCase();
    final status = data['status'] ?? '';
    final timeline = data['timeline'] ?? '';
    final formattedTimeline = timeline.toString().isNotEmpty
        ? DateFormat.yMMMd().format(DateTime.tryParse(timeline.toString()) ?? DateTime.now())
        : 'N/A';

    final loc = _effectiveLocation(data);
    final community = loc['community'] ?? '';
    final subDistrict = loc['subDistrict'] ?? '';
    String locationDisplay;
    if (community.isNotEmpty) {
      locationDisplay = community + (subDistrict.isNotEmpty ? ' · $subDistrict' : '');
    } else if (loc['district']?.isNotEmpty == true) {
      locationDisplay = loc['district']!;
    } else if (loc['region']?.isNotEmpty == true) {
      locationDisplay = loc['region']!;
    } else {
      locationDisplay = 'N/A';
    }

    Color statusColor = Colors.grey;
    if (status == 'suspected') statusColor = Colors.orange;
    if (status == 'confirmed') statusColor = Colors.red;
    if (status == 'not a case') statusColor = Colors.green;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          builder: (_) => CaseViewBottomSheet(caseData: data),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 3,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(caseType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(status.toString().toUpperCase(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor)),
          ]),
          const SizedBox(height: 4),
          Text.rich(TextSpan(
            text: 'Reported: ',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            children: [TextSpan(text: '$formattedTimeline · $locationDisplay', style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87))],
          )),
          Text.rich(TextSpan(
            text: 'Patient: ',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            children: [TextSpan(text: '${patient['gender'] ?? ''}, ${patient['age'] ?? ''}yrs · ${patient['status'] ?? ''}', style: const TextStyle(color: Colors.black87))],
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 16),
            Text(
              'All Reported Cases (${allCases.length})',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.95 * 255).toInt()),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: DropdownButtonFormField<String>(
                      value: selectedFilter,
                      onChanged: (v) => setState(() => selectedFilter = v!),
                      items: filterOptions.map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                      decoration: InputDecoration(
                        labelText: 'Filter by',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : getFilteredCases().isEmpty
                            ? const Center(child: Text('No cases match your filter.'))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                itemCount: getFilteredCases().length,
                                itemBuilder: (ctx, i) => caseSummaryCard(getFilteredCases()[i]),
                              ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
