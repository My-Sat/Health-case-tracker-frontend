import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'all_cases_screen.dart';
import 'case_types_stats.dart';
import 'facility_list_screen.dart';
import 'archived_facility_screen.dart';
import 'login_screen.dart';
import 'create_case_type_screen.dart';
import 'case_type_list_screen.dart';
import 'archived_case_type_screen.dart';
import 'create_facility_screen.dart';
import 'create_case_screen.dart';
import 'my_cases_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loading = true;
  String? _error;

  int _totalCases = 0;
  int _facilityCount = 0; // active facilities count
  int _facilityArchivedCount = 0; // archived facilities count
  int _confirmedCount = 0;

  // case-type counts for action row
  int _caseTypeCount = 0;
  int _caseTypeArchivedCount = 0;

  // all case types returned by the backend (sorted descending by total)
  List<CaseTypeShort> _caseTypes = [];

  // API base
  final String _base = 'https://health-case-tracker-backend-o82a.onrender.com/api';

  // display control — now 3 columns so three cards fit in a row
  static const int _columns = 3;
  static const int _initialRows = 2; // two horizontal lines (rows)
  static const int _initialVisibleCount = _columns * _initialRows; // 6 visible initially
  bool _isExpanded = false;

  // bottom nav
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<String> _token() async {
    return Provider.of<AuthProvider>(context, listen: false).user!.token;
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([_loadCounts(), _loadCaseTypeSummary()]);
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard data';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadCounts() async {
    final token = await _token();

    List<dynamic> allCases = [];

    try {
      final primary = await http.get(Uri.parse('$_base/cases/all-officers'), headers: {'Authorization': 'Bearer $token'});
      if (primary.statusCode == 200) {
        allCases = jsonDecode(primary.body) as List<dynamic>;
      } else {
        final root = await http.get(Uri.parse('$_base/cases'), headers: {'Authorization': 'Bearer $token'});
        if (root.statusCode == 200) {
          allCases = jsonDecode(root.body) as List<dynamic>;
        } else {
          allCases = [];
        }
      }
    } catch (_) {
      allCases = [];
    }

    int confirmed = 0;
    for (final c in allCases) {
      try {
        final s = (c['status'] ?? '').toString().toLowerCase();
        if (s == 'confirmed') confirmed++;
      } catch (_) {}
    }

    // Facility counts for admin:
    int facilityCount = 0;
    int facilityArchived = 0;
    try {
      final resp = await http.get(Uri.parse('$_base/facilities'), headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List list = jsonDecode(resp.body) as List;
        facilityCount = list.length;
      } else {
        facilityCount = 0;
      }
    } catch (_) {
      facilityCount = 0;
    }

    try {
      final resp = await http.get(Uri.parse('$_base/facilities/archived'), headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List list = jsonDecode(resp.body) as List;
        facilityArchived = list.length;
      } else {
        facilityArchived = 0;
      }
    } catch (_) {
      facilityArchived = 0;
    }

    // Case-type counts for action row (active & archived)
    int caseTypeCount = 0;
    int caseTypeArchived = 0;
    try {
      final resp = await http.get(Uri.parse('$_base/casetypes'), headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List list = jsonDecode(resp.body) as List;
        caseTypeCount = list.length;
      } else {
        caseTypeCount = 0;
      }
    } catch (_) {
      caseTypeCount = 0;
    }

    try {
      final resp = await http.get(Uri.parse('$_base/casetypes/archived'), headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List list = jsonDecode(resp.body) as List;
        caseTypeArchived = list.length;
      } else {
        caseTypeArchived = 0;
      }
    } catch (_) {
      caseTypeArchived = 0;
    }

    setState(() {
      _totalCases = allCases.length;
      _confirmedCount = confirmed;
      _facilityCount = facilityCount;
      _facilityArchivedCount = facilityArchived;
      _caseTypeCount = caseTypeCount;
      _caseTypeArchivedCount = caseTypeArchived;
    });
  }

  Future<void> _loadCaseTypeSummary() async {
    final token = await _token();
    try {
      final resp = await http.get(Uri.parse('$_base/cases/type-summary'), headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body) as List;
        final List<CaseTypeShort> items = data.map((e) {
          final name = (e['name'] ?? '').toString();
          final total = int.tryParse((e['total'] ?? 0).toString()) ?? 0;
          final id = (e['caseTypeId'] ?? '').toString();
          return CaseTypeShort(id: id, name: name, total: total);
        }).toList();

        items.sort((a, b) => b.total.compareTo(a.total));
        setState(() {
          _caseTypes = items;
          if (_caseTypes.length <= _initialVisibleCount) _isExpanded = true;
        });
      } else {
        setState(() {
          _caseTypes = [];
        });
      }
    } catch (_) {
      setState(() {
        _caseTypes = [];
      });
    }
  }

  Future<void> _openAllCases() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCasesScreen()));
    _refreshAll();
  }

  Future<void> _openCaseTypeStats() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CaseTypeStatsScreen()));
    _refreshAll();
  }

  Future<void> _openFacilities() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const FacilityListScreen()));
    _refreshAll();
  }

  Future<void> _openArchivedFacilities() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivedFacilityScreen()));
    _refreshAll();
  }

  // navigation helpers for case-type screens
  Future<void> _openCreateCaseType() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCaseTypeScreen()));
    await _refreshAll();
  }

  Future<void> _openCaseTypesList() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CaseTypeListScreen()));
    await _refreshAll();
  }

  Future<void> _openArchivedCaseTypes() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivedCaseTypeScreen()));
    await _refreshAll();
  }

  // NEW: navigation helper for create facility
  Future<void> _openCreateFacility() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFacilityScreen()));
    await _refreshAll();
  }

  // helper to check admin role (used to render drawer items same as HomeScreen)
  bool authIsAdmin(BuildContext context) =>
      Provider.of<AuthProvider>(context, listen: false).user?.role == 'admin';

  Widget _buildTopCountsRow() {
    Widget smallCard({required String label, required int count, required VoidCallback? onTap}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(count.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Facility card with small archived badge on the right (tappable)
    Widget facilityCard() {
      return Expanded(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openFacilities,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_facilityCount.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Facilities', style: TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 8)),
                GestureDetector(
                  onTap: _openArchivedFacilities,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _facilityArchivedCount > 99 ? '99+' : _facilityArchivedCount.toString(),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const SizedBox(height: 4),
                        Text('Archived', style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        facilityCard(),
        const SizedBox(width: 8),
        smallCard(label: 'All cases', count: _totalCases, onTap: _openAllCases),
        const SizedBox(width: 8),
        smallCard(label: 'Confirmed', count: _confirmedCount, onTap: null),
      ],
    );
  }

  // Updated: second small-card row for case-type actions — case-types card includes archived-badge at right, Add facility on the right
  Widget _buildCaseTypeActionsRow() {
    Widget actionCard({required String label, required VoidCallback? onTap, required IconData icon}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 18, color: Colors.teal.shade800),
                  ),
                  const SizedBox(height: 8),
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Case types card with archived badge on the right (compact, like facilityCard)
    Widget caseTypesCard() {
      return Expanded(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openCaseTypesList,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_caseTypeCount.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Case types', style: TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 8)),
                GestureDetector(
                  onTap: _openArchivedCaseTypes,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _caseTypeArchivedCount > 99 ? '99+' : _caseTypeArchivedCount.toString(),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const SizedBox(height: 4),
                        Text('Archived', style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        actionCard(label: 'Add case type', onTap: _openCreateCaseType, icon: Icons.add),
        const SizedBox(width: 8),
        caseTypesCard(),
        const SizedBox(width: 8),
        actionCard(label: 'Add facility', onTap: _openCreateFacility, icon: Icons.add_business),
      ],
    );
  }

  Widget _buildCaseTypeGrid() {
    final visibleList = _isExpanded ? _caseTypes : _caseTypes.take(_initialVisibleCount).toList();
    final tiles = <Widget>[];

    for (final t in visibleList) {
      tiles.add(_CaseTypeTile(name: t.name, count: t.total));
    }

    // If collapsed and there are more items than visible, add an inline "View more" tile at the end.
    if (!_isExpanded && _caseTypes.length > _initialVisibleCount) {
      tiles.add(_InlineExpandTile(
        label: 'View more',
        onTap: () => setState(() => _isExpanded = true),
      ));
    } else if (_isExpanded && _caseTypes.length > _initialVisibleCount) {
      // When expanded, show a "Show less" tile to collapse back
      tiles.add(_InlineExpandTile(
        label: 'Show less',
        onTap: () => setState(() => _isExpanded = false),
      ));
    }

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: _columns,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // childAspectRatio tuned for 3-column layout (wider/shorter tiles)
      childAspectRatio: 1.8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: tiles,
    );
  }

  Widget _dashboardContent() {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Top counts cards AND case-type action cards inside the same white container.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopCountsRow(),
              const SizedBox(height: 8),
              _buildCaseTypeActionsRow(),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Case type summary header with "View Details" and admin-specific case-type actions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Expanded(
                child: Text('Reported Case Types', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              TextButton(
                onPressed: _openCaseTypeStats,
                child: const Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // case type grid (inside white rounded container)
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _caseTypes.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(_error ?? 'No case type summary available', style: TextStyle(color: Colors.grey.shade700)),
                        )
                      : _buildCaseTypeGrid(),
                  const SizedBox(height: 12),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build a nav icon widget with optional badge and active highlight.
  Widget _buildNavIcon(IconData iconData, int badgeCount, bool active) {
    final bgColor = active ? Colors.teal.shade50 : Colors.transparent;
    final iconColor = active ? Colors.teal.shade800 : Colors.grey[700];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(iconData, size: 20, color: iconColor),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show full AppBar only on the Dashboard tab; hide it on the Cases tab so there's no empty space.
    final bool showAppBar = _selectedIndex == 0;

    return Scaffold(
      key: _scaffoldKey,
      appBar: showAppBar
          ? AppBar(
              title: const Text('Admin Dashboard'),
              centerTitle: true,
            )
          : null,
      // keep drawer as before (accessible via overlay menu button when AppBar is hidden).
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text('Health Case Tracker', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            if (authIsAdmin(context))
              ExpansionTile(
                leading: const Icon(Icons.business),
                title: const Text('Facility'),
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_business),
                    title: const Text('Add Facility'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _openCreateFacility();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.list),
                    title: const Text('Facilities'),
                    onTap: () async {
                      Navigator.pop(context); // close drawer first
                      await _openFacilities();
                    },
                  ),
                ],
              ),
            ExpansionTile(
              leading: const Icon(Icons.category),
              title: const Text('Cases'),
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Reported'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add Case Type'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _openCreateCaseType();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('Case Types'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _openCaseTypesList();
                  },
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archives'),
              children: [
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('Archived Facilities'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _openArchivedFacilities();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('Archived Case Types'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _openArchivedCaseTypes();
                  },
                ),
              ],
            ),
            if (!authIsAdmin(context)) ...[
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Report Case'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCaseScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text('My Cases'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCasesScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('All Cases'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCasesScreen()));
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                await auth.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.teal.shade800, Colors.teal.shade300], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _dashboardContent(),
                        // embedded AllCasesScreen so admin can switch tabs without leaving dashboard
                        const AllCasesScreen(),
                      ],
                    ),
            ),
          ),

          // If AppBar is hidden (Cases tab), show a small floating menu button to open drawer
          if (!showAppBar)
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Center(
                      child: Icon(Icons.menu, color: Colors.teal.shade800),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal.shade800,
        unselectedItemColor: Colors.grey.shade700,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        onTap: (i) async {
          setState(() {
            _selectedIndex = i;
          });

          if (i == 0) {
            await _refreshAll();
          } else if (i == 1) {
            // show embedded AllCasesScreen — keep admin dashboard in the tab stack
            // refresh counts/case-types while switching
            await _loadCounts();
            await _loadCaseTypeSummary();
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.dashboard, 0, _selectedIndex == 0),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.list, _totalCases, _selectedIndex == 1),
            label: 'Cases',
          ),
        ],
      ),
    );
  }
}

///// Simple model used by the dashboard to display case type summary
class CaseTypeShort {
  final String id;
  final String name;
  final int total;
  CaseTypeShort({required this.id, required this.name, required this.total});
}

/// Reduced-size case type tile suitable for 3-per-row layout
class _CaseTypeTile extends StatelessWidget {
  final String name;
  final int count;
  const _CaseTypeTile({required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(count.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineExpandTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _InlineExpandTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(label == 'View more' ? Icons.expand_more : Icons.expand_less, color: Colors.grey.shade700, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
