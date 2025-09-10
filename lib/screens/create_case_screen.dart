// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/health_facility.dart';

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  _CreateCaseScreenState createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // toggles for Add new / Select existing
  bool addingRegion = false;
  bool addingDistrict = false;
  bool addingSubDistrict = false;
  bool addingCommunity = false;

  // dropdown selections + controllers
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

  // case type
  List<dynamic> caseTypes = [];
  dynamic selectedCaseType;

  String gender = 'male';
  String patientStatus = 'Ongoing treatment';
  bool isSubmitting = false;

  /// Always false so location UI is shown and prefilled on load
  bool useFacilityCommunity = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadCaseTypes();
      await loadRegions();
      // Since useFacilityCommunity is always false, prefill facility location on load
      if (!useFacilityCommunity) {
        await prefillFacilityLocation();
      }
    });
  }

  // ---------- utilities ----------
  bool _looksLikeObjectId(String? s) {
    if (s == null) return false;
    final re = RegExp(r'^[a-fA-F0-9]{24}$');
    return re.hasMatch(s);
  }

  String _nameOf(dynamic v) {
    if (v == null) return '';
    if (v is Map) return (v['name'] ?? '').toString();
    return v.toString();
  }

  // Attempt to fetch populated facility if local user facility has ids
  Future<HealthFacility?> _resolveFacilityWithNames() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return null;

    // prefer typed HealthFacility model if provided
    final hfAny = (user as dynamic).healthFacility;
    String? facilityId;

    if (hfAny is HealthFacility) {
      facilityId = hfAny.id;
      // if it already has readable names, no need to fetch
      if (!_looksLikeObjectId(hfAny.location.region) &&
          !_looksLikeObjectId(hfAny.location.district)) {
        return hfAny;
      }
    } else if (hfAny is Map) {
      facilityId = (hfAny['_id'] ?? hfAny['id'])?.toString();
      final loc = hfAny['location'] ?? hfAny;
      final r = _nameOf(loc['region']);
      final d = _nameOf(loc['district']);
      if (!_looksLikeObjectId(r) && !_looksLikeObjectId(d)) {
        try {
          return HealthFacility.fromJson(Map<String, dynamic>.from(hfAny));
        } catch (_) {
          // ignore, will fetch below
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

  // Prefill region/district/subDistrict/community with readable names
  Future<void> prefillFacilityLocation() async {
    final populated = await _resolveFacilityWithNames();
    if (populated == null) return;

    // Extract names (Location in our model already normalizes map->name)
    final preRegion = populated.location.region;
    final preDistrict = populated.location.district;
    final preSubDistrict = populated.location.subDistrict ?? '';
    final preCommunity = populated.location.community;

    if (preRegion.isEmpty || preDistrict.isEmpty) return;

    // Set base selections safely
    setState(() {
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

    // Ensure region list contains region
    if (!regions.contains(preRegion)) {
      setState(() => regions = [...regions, preRegion]);
    }

    // Cascade-load and select
    await loadDistricts(preRegion);
    if (mounted) {
      if (!districts.contains(preDistrict)) {
        setState(() => districts = [...districts, preDistrict]);
      }
      setState(() => selectedDistrict = preDistrict);
    }

    // load subdistricts and communities
    await loadSubDistricts(preRegion, preDistrict);
    if (mounted && preSubDistrict.isNotEmpty) {
      if (!subDistricts.contains(preSubDistrict)) {
        setState(() => subDistricts = [...subDistricts, preSubDistrict]);
      }
      setState(() => selectedSubDistrict = preSubDistrict);
    }

    await loadCommunities(preRegion, preDistrict, preSubDistrict.isEmpty ? null : preSubDistrict);
    if (mounted && preCommunity.isNotEmpty) {
      if (!communities.contains(preCommunity)) {
        setState(() => communities = [...communities, preCommunity]);
      }
      setState(() => selectedCommunity = preCommunity);
    }
  }

  // ---------- data loads ----------
  Future<void> loadCaseTypes() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/casetypes'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        setState(() {
          caseTypes = List<dynamic>.from(list);
          selectedCaseType = null;
        });
      }
    } catch (_) {}
  }

  Future<void> loadRegions() async {
    try {
      final data = await ApiService.fetchRegions();
      setState(() => regions = data);
    } catch (_) {}
  }

  Future<void> loadDistricts(String region) async {
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

  Future<void> loadSubDistricts(String region, String district) async {
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

  Future<void> loadCommunities(String region, String district, String? subDistrict) async {
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

  // ---------- submit ----------
  Future<void> submitCase() async {
    if (selectedCaseType == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please pick a case type')));
      return;
    }

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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.user!.token;

    final regionName = addingRegion ? regionCtrl.text.trim() : selectedRegion;
    final districtName = addingDistrict ? districtCtrl.text.trim() : selectedDistrict;
    final subDistrictName =
        addingSubDistrict ? subDistrictCtrl.text.trim() : selectedSubDistrict;
    final communityName = addingCommunity ? communityCtrl.text.trim() : selectedCommunity;

    final body = {
      'caseType': selectedCaseType['_id'],
      'community': useFacilityCommunity ? null : communityName,
      'location': useFacilityCommunity
          ? null
          : {
              'region': regionName,
              'district': districtName,
              if (subDistrictName != null && subDistrictName.isNotEmpty)
                'subDistrict': subDistrictName,
            },
      'patient': {
        'name': nameCtrl.text.trim(),
        'age': int.tryParse(ageCtrl.text.trim()) ?? 0,
        'gender': gender,
        'phone': phoneCtrl.text.trim(),
        'status': patientStatus,
      },
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/cases'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      setState(() => isSubmitting = false);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Case reported')));
        Navigator.pop(context);
      } else {
        final msg = () {
          try {
            return jsonDecode(response.body)['message'] ?? 'Failed to report case';
          } catch (_) {
            return 'Failed to report case';
          }
        }();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (err) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $err')));
    }
  }

  // ---------- UI pieces ----------
  Widget buildInput(String label, IconData icon, TextEditingController controller,
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

  Widget buildLocationDropdownSection() {
    return Column(
      children: [
        // REGION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Region", style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => setState(() {
                addingRegion = !addingRegion;
                if (!addingRegion) regionCtrl.clear();
              }),
              child: Text(addingRegion ? "Select existing" : "Add new"),
            ),
          ],
        ),
        addingRegion
            ? buildInput("Enter Region", Icons.map, regionCtrl)
            : DropdownButtonFormField<String>(
                value: regions.contains(selectedRegion) ? selectedRegion : null,
                items: regions
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
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
                  if (val != null) await loadDistricts(val);
                },
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
        const SizedBox(height: 16),

        // DISTRICT
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("District", style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => setState(() {
                addingDistrict = !addingDistrict;
                if (!addingDistrict) districtCtrl.clear();
              }),
              child: Text(addingDistrict ? "Select existing" : "Add new"),
            ),
          ],
        ),
        addingDistrict
            ? buildInput("Enter District", Icons.location_city, districtCtrl)
            : DropdownButtonFormField<String>(
                value: districts.contains(selectedDistrict) ? selectedDistrict : null,
                items: districts
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) async {
                  setState(() {
                    selectedDistrict = val;
                    selectedSubDistrict = null;
                    selectedCommunity = null;
                    subDistricts = [];
                    communities = [];
                  });
                  if (selectedRegion != null && val != null) {
                    // load sub-districts and immediately also load all communities under the district
                    await loadSubDistricts(selectedRegion!, val);
                    if (!addingCommunity) {
                      await loadCommunities(selectedRegion!, val, null);
                    }
                  }
                },
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
        const SizedBox(height: 16),

        // SUB-DISTRICT
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Sub-District", style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => setState(() {
                addingSubDistrict = !addingSubDistrict;
                if (!addingSubDistrict) subDistrictCtrl.clear();
              }),
              child: Text(addingSubDistrict ? "Select existing" : "Add new"),
            ),
          ],
        ),
        addingSubDistrict
            ? buildInput("Enter Sub-District", Icons.location_on, subDistrictCtrl)
            : DropdownButtonFormField<String>(
                value: subDistricts.contains(selectedSubDistrict) ? selectedSubDistrict : null,
                items: subDistricts
                    .map((sd) => DropdownMenuItem(value: sd, child: Text(sd)))
                    .toList(),
                onChanged: (val) async {
                  setState(() {
                    selectedSubDistrict = val;
                    selectedCommunity = null;
                    communities = [];
                  });
                  if (selectedRegion != null && selectedDistrict != null) {
                    await loadCommunities(selectedRegion!, selectedDistrict!, val);
                  }
                },
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
        const SizedBox(height: 16),

        // COMMUNITY
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Community", style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () async {
                setState(() {
                  addingCommunity = !addingCommunity;
                  if (addingCommunity == false) communityCtrl.clear();
                });
                // If switching to "Select existing", load communities for the current region/district/subDistrict
                if (!addingCommunity &&
                    selectedRegion != null &&
                    selectedDistrict != null) {
                  await loadCommunities(
                    selectedRegion!,
                    selectedDistrict!,
                    selectedSubDistrict,
                  );
                }
              },
              child: Text(addingCommunity ? "Select existing" : "Add new"),
            ),
          ],
        ),
        addingCommunity
            ? buildInput("Enter Community", Icons.home, communityCtrl)
            : DropdownButtonFormField<String>(
                value: communities.contains(selectedCommunity) ? selectedCommunity : null,
                items: communities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => selectedCommunity = val),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
      ],
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
                    'Report New Case',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // case type
                  DropdownButtonFormField<dynamic>(
                    value: selectedCaseType,
                    hint: const Text("Select a case type"),
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

                  // patient fields
                  buildInput('Patient Name', Icons.person, nameCtrl),
                  const SizedBox(height: 16),
                  buildInput('Patient Age', Icons.numbers, ageCtrl, type: TextInputType.number),
                  const SizedBox(height: 16),
                  buildInput('Patient Phone', Icons.phone, phoneCtrl, type: TextInputType.phone),
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

                  // Location UI is always shown now (useFacilityCommunity is false)
                  const SizedBox(height: 16),
                  buildLocationDropdownSection(),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : submitCase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    ),
                    child: Text(isSubmitting ? 'Submitting...' : 'Submit Case'),
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
