import 'package:flutter/material.dart';
import 'package:fusion/models/profile.dart';
import 'package:fusion/Components/side_drawer2.dart';
import 'package:fusion/screens/Department/Student_details/filter.dart';
import 'package:fusion/services/department_service.dart';
import 'package:fusion/services/service_locator.dart';
import 'package:fusion/services/storage_service.dart';

class BatchDetails extends StatefulWidget {
  final String selectedProgramme;
  final Map<String, String> selectedDepartmentData;
  BatchDetails(
      {required this.selectedProgramme, required this.selectedDepartmentData});

  @override
  _BatchDetailsState createState() => _BatchDetailsState();
}

enum StudentSortingCriteria { cpi, currentSemesterNo }

class _BatchDetailsState extends State<BatchDetails>
    with SingleTickerProviderStateMixin {
  late int bid;
  ProfileData? data;
  late TabController _tabController;
  List<Map<String, dynamic>> batchDetails = [];
  var service = locator<StorageService>();
  late String curr_desig = service.getFromDisk("Current_designation");
  StudentSortingCriteria? _sortingCriteria;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    var service = locator<StorageService>();
    data = service.profileData;
    bid =
        generateBid(widget.selectedProgramme, widget.selectedDepartmentData, 1);
    _tabController = TabController(
      length: _calculateTabCount(),
      vsync: this,
    );
    _tabController.addListener(_handleTabSelection);
    _tabController.index = 0;
  }

  int _calculateTabCount() {
    int tabCount = 0;
    String programme = widget.selectedProgramme;
    if (programme == 'PhD') {
      tabCount = 1;
    } else if (programme == 'M.Tech') {
      tabCount = 2;
    } else if (programme == 'B.Tech') {
      tabCount = 4;
    }
    return tabCount;
  }

  void _handleTabSelection() {
    int year = _tabController.index + 1;
    int newBid = generateBid(
        widget.selectedProgramme, widget.selectedDepartmentData, year);
    if (bid != newBid) {
      bid = newBid;
      DepartmentService().getStudents(bid).then((data) {
        setState(() {
          batchDetails = data ?? [];
        });
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _sortStudents(List<Map<String, dynamic>> students) {
    if (_sortingCriteria == StudentSortingCriteria.cpi) {
      students.sort((a, b) => a['cpi'].compareTo(b['cpi']));
    } else if (_sortingCriteria == StudentSortingCriteria.currentSemesterNo) {
      students.sort(
          (a, b) => a['curr_semester_no'].compareTo(b['curr_semester_no']));
    }
    if (!_isAscending) {
      students = students.reversed.toList();
    }
    setState(() {
      batchDetails = students;
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _isAscending = !_isAscending;
    });
    _sortStudents(batchDetails);
  }

  void _setSortingCriteria(StudentSortingCriteria? criteria) {
    setState(() {
      _sortingCriteria = criteria;
    });
    _sortStudents(batchDetails);
  }

  void applyFilters(Map<String, Map<String, bool>> selectedFilters) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Students',
          style: TextStyle(fontSize: 25, color: Colors.white),
        ),
        actions: <Widget>[
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.search),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.notifications),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.more_vert),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 6.0,
          controller: _tabController,
          tabs: _buildTabs(),
        ),
      ),
      drawer: SideDrawer(
        curr_desig: curr_desig,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: DropdownButton<StudentSortingCriteria>(
                    hint: Text('Sort by'),
                    value: _sortingCriteria,
                    onChanged: _setSortingCriteria,
                    items: [
                      DropdownMenuItem(
                        child: Text('Sort by CPI'),
                        value: StudentSortingCriteria.cpi,
                      ),
                      DropdownMenuItem(
                        child: Text('Sort by Semester No'),
                        value: StudentSortingCriteria.currentSemesterNo,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                    _isAscending ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: _toggleSortOrder,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 5.0),
                child: IconButton(
                  icon: Icon(Icons.filter_list),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              FilterScreen(onApplyFilters: applyFilters)),
                    );
                  },
                ),
              ),
            ],
          ),
          Expanded(
            child: Container(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: DepartmentService().getStudents(bid),
                      builder: ((context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else {
                          batchDetails = snapshot.data ?? [];
                          return batchDetails.isNotEmpty
                              ? DataTable(
                                  columns: batchDetails.first.entries
                                      .map(
                                        (entry) => DataColumn(
                                          label: Text(
                                            entry.key.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  rows: batchDetails
                                      .map(
                                        (batch) => DataRow(
                                          cells: batch.entries
                                              .map(
                                                (entry) => DataCell(
                                                  Text(
                                                      entry.value?.toString() ??
                                                          ''),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      )
                                      .toList(),
                                )
                              : Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'No data available',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                );
                        }
                      }),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildTabs() {
    List<Widget> tabs = [];
    String programme = widget.selectedProgramme;
    if (programme == 'PhD') {
      tabs.add(Tab(
        child: Text(
          '${widget.selectedProgramme}  ',
        ),
      ));
    } else if (programme == 'M.Tech') {
      tabs.add(Tab(
        child: Text(
          'M.Tech 1st Year',
        ),
      ));
      tabs.add(Tab(
        child: Text(
          'M.Tech 2nd Year',
        ),
      ));
    } else if (programme == 'B.Tech') {
      tabs.add(Tab(
        child: Text(
          'B.Tech 1st Year',
        ),
      ));
      tabs.add(Tab(
        child: Text(
          'B.Tech 2nd Year',
        ),
      ));
      tabs.add(Tab(
        child: Text(
          'B.Tech 3rd Year',
        ),
      ));
      tabs.add(Tab(
        child: Text(
          'B.Tech 4th Year',
        ),
      ));
    }
    return tabs;
  }

  int generateBid(
      String programme, Map<String, String> departmentData, int year) {
    String departmentCode =
        widget.selectedDepartmentData['departmentCode'] ?? '';
    String bid = departmentCode;
    Map<String, int> batchLengths = {
      'PhD': 6,
      'M.Tech': 4,
      'B.Tech': 1,
    };
    if (programme == 'PhD') {
      bid += '1'.padRight(batchLengths[programme]!, '1');
    } else if (programme == 'M.Tech') {
      bid += '1'.padRight(batchLengths[programme]! + (year == 2 ? 1 : 0), '1');
    } else if (programme == 'B.Tech') {
      if (year == 1) bid = bid;
      if (year == 2) bid += '1'.padRight(batchLengths[programme]!, '1');
      if (year == 3) bid += '1'.padRight(batchLengths[programme]! + 1, '1');
      if (year == 4) bid += '1'.padRight(batchLengths[programme]! + 2, '1');
    }
    return int.parse(bid);
  }
}
