// lib/screens/edit_case_screen.dart
// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/health_facility.dart';

class EditCaseScreen extends StatefulWidget {
  final Map<String, dynamic> caseData;
  const EditCaseScreen({super.key, required this.caseData});

  @override
  _EditCaseScreenState createState() => _EditCaseScreenState();
}

class _EditCaseScreenState extends State<EditCaseScreen> {
  // Patient fields
  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // Case type & statuses
  List<dynamic> caseTypes = [];
  dynamic selectedCaseType;
  String gender = 'male';
  String patientStatus = 'Ongoing treatment';
  String caseStatus = 'suspected';

  // Facility vs outside community
  bool useFacilityCommunity = true;

  // Cascading location (outside facility)
  bool addingRegion = false;
  bool addingDistrict = false;
  bool addingSubDistrict = false;
  bool addingCommunity = false;

  List<String> regions = [];
  String? selectedRegion;
  final regionCtrl = TextEditingController();

  List<String> districts = [];
  String? selectedDistrict;
  final districtCtrl = TextEditingController();

  List<String> subDistricts = [];
  String? selectedSubDistrict;
  final subDistrictCtrl = TextEditingController();

  List<String> communities = [];
  String? selectedCommunity;
  final communityCtrl = TextEditingController();

  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillBasicFields();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCaseTypes();
      await _loadRegions();
      // Use populated facility names (not IDs) to seed dropdowns
      await _prefillFacilityLocation();

      // If case has an outside community already, try to set it
      final cc = widget.caseData['community'];
      if (cc != null) {
        final ccName = _nameOf(cc, '');
        if (ccName.isNotEmpty && selectedRegion != null && selectedDistrict != null) {
          await _loadCommunities(selectedRegion!, selectedDistrict!, selectedSubDistrict);
          if (!communities.contains(ccName)) {
            setState(() => communities = [...communities, ccName]);
          }
          setState(() => selectedCommunity = ccName);
        }
      }
    });
  }

  // ---------- helpers ----------
  bool _looksLikeObjectId(String? s) {
    if (s == null) return false;
    final re = RegExp(r'^[a-fA-F0-9]{24}$');
    return re.hasMatch(s);
  }

  String _nameOf(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    if (v is Map) return (v['name'] ?? fallback).toString();
    return v.toString();
  }

  void _ensureInList(List<String> list, String? value) {
    if (value == null || value.isEmpty) return;
    if (!list.contains(value)) list.add(value);
  }

  // ---------- prefill & loads ----------

  void _prefillBasicFields() {
    final c = widget.caseData;
    final patient = (c['patient'] ?? {}) as Map<String, dynamic>;

    nameCtrl.text = (patient['name'] ?? '').toString();
    ageCtrl.text = (patient['age'] ?? '').toString();
    phoneCtrl.text = (patient['phone'] ?? '').toString();
    gender = (patient['gender'] ?? gender).toString();
    patientStatus = (patient['status'] ?? patientStatus).toString();
    caseStatus = (c['status'] ?? caseStatus).toString();

    // If the case has a specific community set (not null), it’s outside facility
    useFacilityCommunity = c['community'] == null;
  }

  Future<void> _loadCaseTypes() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/casetypes'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final caseTypeId = (() {
          final ct = widget.caseData['caseType'];
          if (ct is Map) return ct['_id']?.toString();
          return ct?.toString();
        })();

        setState(() {
          caseTypes = list;
          selectedCaseType = caseTypeId == null
              ? (list.isNotEmpty ? list.first : null)
              : list.firstWhere(
                  (ct) => ct['_id']?.toString() == caseTypeId,
                  orElse: () => (list.isNotEmpty ? list.first : null),
                );
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRegions() async {
    try {
      final data = await ApiService.fetchRegions();
      setState(() => regions = data);
    } catch (_) {}
  }

  Future<void> _loadDistricts(String region) async {
    try {
      final data = await ApiService.fetchDistricts(region);
      setState(() {
        districts = data;
        selectedDistrict = null;
        subDistricts = [];
        selectedSubDistrict = null;
        communities = [];
        selectedCommunity = null;
      });
    } catch (_) {}
  }

  Future<void> _loadSubDistricts(String region, String district) async {
    try {
      final data = await ApiService.fetchSubDistricts(region, district);
      setState(() {
        subDistricts = data;
        selectedSubDistrict = null;
        communities = [];
        selectedCommunity = null;
      });
    } catch (_) {}
  }

  Future<void> _loadCommunities(String region, String district, String? subDistrict) async {
    try {
      final data = await ApiService.fetchCommunities(
        region: region,
        district: district,
        subDistrict: subDistrict,
      );
      setState(() {
        communities = data;
        selectedCommunity = null;
      });
    } catch (_) {}
  }

  /// Resolve the officer's facility with human‑readable location names.
  /// Falls back to fetching `/facilities/:id` if the local object has ObjectId‑like strings.
  Future<HealthFacility?> _resolveFacilityWithNames() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return null;

    final hfAny = (user as dynamic).healthFacility;
    String? facilityId;

    if (hfAny is HealthFacility) {
      facilityId = hfAny.id;
      // Already readable? then use as-is
      if (!_looksLikeObjectId(hfAny.location.region) &&
          !_looksLikeObjectId(hfAny.location.district)) {
        return hfAny;
      }
    } else if (hfAny is Map) {
      facilityId = (hfAny['_id'] ?? hfAny['id'])?.toString();
      final loc = hfAny['location'] ?? hfAny;
      final r = _nameOf(loc['region']);
      final d = _nameOf(loc['district']);
      // If not ObjectIds, we can parse into model directly
      if (!_looksLikeObjectId(r) && !_looksLikeObjectId(d)) {
        try {
          return HealthFacility.fromJson(Map<String, dynamic>.from(hfAny));
        } catch (_) {
          // fall through to fetch
        }
      }
    }

    if (facilityId == null || facilityId.isEmpty) return null;

    try {
      final populated = await ApiService.fetchFacilityById(
        id: facilityId,
        token: user.token,
      );
      return populated;
    } catch (_) {
      return null;
    }
  }

  Future<void> _prefillFacilityLocation() async {
    final populated = await _resolveFacilityWithNames();
    if (populated == null) return;

    final preRegion = populated.location.region;
    final preDistrict = populated.location.district;
    final preSubDistrict = populated.location.subDistrict ?? '';
    final preCommunity = populated.location.community;

    if (preRegion.isEmpty || preDistrict.isEmpty) return;

    setState(() {
      // seed with facility names to guide outside‑facility pickers
      addingRegion = false;
      addingDistrict = false;
      addingSubDistrict = false;
      addingCommunity = false;

      selectedRegion = preRegion;
      selectedDistrict = null;
      selectedSubDistrict = null;
      selectedCommunity = null;

      districts = [];
      subDistricts = [];
      communities = [];
    });

    await _loadDistricts(preRegion);
    if (!mounted) return;

    setState(() {
      _ensureInList(districts, preDistrict);
      selectedDistrict = preDistrict;
    });

    await _loadSubDistricts(preRegion, preDistrict);
    if (!mounted) return;

    if (preSubDistrict.isNotEmpty) {
      setState(() {
        _ensureInList(subDistricts, preSubDistrict);
        selectedSubDistrict = preSubDistrict;
      });
    }

    await _loadCommunities(preRegion, preDistrict, selectedSubDistrict);
    if (!mounted) return;

    if (preCommunity.isNotEmpty) {
      setState(() {
        _ensureInList(communities, preCommunity);
        selectedCommunity = preCommunity;
      });
    }
  }

  // ---------- submit ----------
  Future<void> _submitUpdate() async {
    if (!useFacilityCommunity) {
      final r = addingRegion ? regionCtrl.text.trim() : (selectedRegion ?? '');
      final d = addingDistrict ? districtCtrl.text.trim() : (selectedDistrict ?? '');
      final c = addingCommunity ? communityCtrl.text.trim() : (selectedCommunity ?? '');
      if (r.isEmpty || d.isEmpty || c.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Region, District and Community are required')),
        );
        return;
      }
    }

    setState(() => isSubmitting = true);
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final regionName = addingRegion ? regionCtrl.text.trim() : selectedRegion;
    final districtName = addingDistrict ? districtCtrl.text.trim() : selectedDistrict;
    final subDistrictName = addingSubDistrict ? subDistrictCtrl.text.trim() : selectedSubDistrict;
    final communityName = addingCommunity ? communityCtrl.text.trim() : selectedCommunity;

    final body = {
      'caseType': selectedCaseType?['_id'],
      'status': caseStatus,
      'community': useFacilityCommunity ? null : communityName,
      'location': useFacilityCommunity
          ? null
          : {
              'region': regionName,
              'district': districtName,
              if (subDistrictName != null && subDistrictName.isNotEmpty) 'subDistrict': subDistrictName,
            },
      'patient': {
        'name': nameCtrl.text.trim(),
        'age': int.tryParse(ageCtrl.text.trim()) ?? 0,
        'gender': gender,
        'phone': phoneCtrl.text.trim(),
        'status': patientStatus,
      },
    };

    final res = await http.put(
      Uri.parse('${ApiService.baseUrl}/cases/${widget.caseData['_id']}/edit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    setState(() => isSubmitting = false);

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case updated successfully')),
      );
      Navigator.pop(context, true);
    } else {
      final msg = () {
        try {
          return jsonDecode(res.body)['message'] ?? 'Failed to update case';
        } catch (_) {
          return 'Failed to update case';
        }
      }();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---------- widgets ----------
  Widget _buildInput(String label, IconData icon, TextEditingController controller,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool isAdding,
    required VoidCallback onToggle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        TextButton(
          onPressed: onToggle,
          child: Text(isAdding ? 'Select Existing' : 'Add New'),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required void Function(String?) onChanged,
  }) {
    final safeValue = (value != null && options.contains(value)) ? value : null;
    return DropdownButtonFormField<String>(
      value: safeValue,
      items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildLocationDropdownSection() {
    return Column(
      children: [
        // REGION
        _buildToggleRow(
          label: 'Region',
          isAdding: addingRegion,
          onToggle: () {
            setState(() {
              addingRegion = !addingRegion;
              if (!addingRegion) regionCtrl.clear();
              selectedRegion = null;
              districts = [];
              subDistricts = [];
              communities = [];
              selectedDistrict = null;
              selectedSubDistrict = null;
              selectedCommunity = null;
            });
          },
        ),
        addingRegion
            ? _buildInput('Enter Region', Icons.map, regionCtrl)
            : _buildDropdownField(
                label: 'Select Region',
                value: selectedRegion,
                options: regions,
                onChanged: (val) async {
                  setState(() {
                    selectedRegion = val;
                    selectedDistrict = null;
                    selectedSubDistrict = null;
                    selectedCommunity = null;
                    districts = [];
                    subDistricts = [];
                    communities = [];
                  });
                  if (val != null) await _loadDistricts(val);
                },
              ),
        const SizedBox(height: 16),

        // DISTRICT
        _buildToggleRow(
          label: 'District',
          isAdding: addingDistrict,
          onToggle: () {
            setState(() {
              addingDistrict = !addingDistrict;
              if (!addingDistrict) districtCtrl.clear();
              selectedDistrict = null;
              subDistricts = [];
              communities = [];
              selectedSubDistrict = null;
              selectedCommunity = null;
            });
          },
        ),
        addingDistrict
            ? _buildInput('Enter District', Icons.location_city, districtCtrl)
            : _buildDropdownField(
                label: 'Select District',
                value: selectedDistrict,
                options: districts,
                onChanged: (val) async {
                  setState(() {
                    selectedDistrict = val;
                    selectedSubDistrict = null;
                    selectedCommunity = null;
                    subDistricts = [];
                    communities = [];
                  });
                  if (selectedRegion != null && val != null) {
                    await _loadSubDistricts(selectedRegion!, val);
                  }
                },
              ),
        const SizedBox(height: 16),

        // SUB-DISTRICT (optional)
        _buildToggleRow(
          label: 'Sub-district (Optional)',
          isAdding: addingSubDistrict,
          onToggle: () {
            setState(() {
              addingSubDistrict = !addingSubDistrict;
              if (!addingSubDistrict) subDistrictCtrl.clear();
              selectedSubDistrict = null;
              communities = [];
              selectedCommunity = null;
            });
          },
        ),
        addingSubDistrict
            ? _buildInput('Enter Sub-district', Icons.location_on, subDistrictCtrl)
            : _buildDropdownField(
                label: 'Select Sub-district',
                value: selectedSubDistrict,
                options: subDistricts,
                onChanged: (val) async {
                  setState(() {
                    selectedSubDistrict = val;
                    selectedCommunity = null;
                    communities = [];
                  });
                  if (selectedRegion != null && selectedDistrict != null) {
                    await _loadCommunities(selectedRegion!, selectedDistrict!, val);
                  }
                },
              ),
        const SizedBox(height: 16),

        // COMMUNITY
        _buildToggleRow(
          label: 'Community',
          isAdding: addingCommunity,
          onToggle: () async {
            setState(() {
              addingCommunity = !addingCommunity;
              if (!addingCommunity) communityCtrl.clear();
              selectedCommunity = null;
            });
            if (!addingCommunity && selectedRegion != null && selectedDistrict != null) {
              await _loadCommunities(selectedRegion!, selectedDistrict!, selectedSubDistrict);
            }
          },
        ),
        addingCommunity
            ? _buildInput('Enter Community', Icons.home, communityCtrl)
            : _buildDropdownField(
                label: 'Select Community',
                value: selectedCommunity,
                options: communities,
                onChanged: (val) => setState(() => selectedCommunity = val),
              ),
      ],
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Case')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.95 * 255).toInt()),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Case',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Case Type
                  DropdownButtonFormField<dynamic>(
                    value: selectedCaseType,
                    items: caseTypes
                        .map((ct) => DropdownMenuItem(
                              value: ct,
                              child: Text(ct['name']),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => selectedCaseType = val),
                    decoration: InputDecoration(
                      labelText: 'Case Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildInput('Patient Name', Icons.person, nameCtrl),
                  const SizedBox(height: 16),
                  _buildInput('Patient Age', Icons.numbers, ageCtrl, type: TextInputType.number),
                  const SizedBox(height: 16),
                  _buildInput('Patient Phone', Icons.phone, phoneCtrl, type: TextInputType.phone),

                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: gender,
                    items: ['male', 'female', 'other']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) => setState(() => gender = val!),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),

                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: caseStatus,
                    items: ['suspected', 'confirmed', 'not a case']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => caseStatus = val!),
                    decoration: InputDecoration(
                      labelText: 'Case Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50]),
                  ),

                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: patientStatus,
                    items: ['Ongoing treatment', 'Recovered', 'Deceased']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => patientStatus = val!),
                    decoration: InputDecoration(
                      labelText: 'Patient Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),

                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: useFacilityCommunity,
                    onChanged: (val) async {
                      setState(() => useFacilityCommunity = val);
                      if (!val) {
                        // About to choose outside community -> seed dropdowns with readable facility names
                        await _prefillFacilityLocation();
                      }
                    },
                    title: const Text("Use Facility Community"),
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (!useFacilityCommunity) ...[
                    const SizedBox(height: 12),
                    _buildLocationDropdownSection(),
                  ],

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : _submitUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    ),
                    child: Text(isSubmitting ? 'Updating...' : 'Update Case'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
