import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:google_fonts/google_fonts.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    try {
      final response = await _apiClient.get('/tasks');
      if (response.statusCode == 200) {
        final List<dynamic> tasks = jsonDecode(response.body);
        final Map<DateTime, List<dynamic>> events = {};

        for (var task in tasks) {
          if (task['dueDate'] != null) {
            final date = DateTime.parse(task['dueDate']);
            final day = DateTime(date.year, date.month, date.day);
            if (events[day] == null) {
              events[day] = [];
            }
            events[day]!.add(task);
          }
        }

        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'CALENDAR OPERATIV',
          style: GoogleFonts.robotoSlab(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.red),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2020, 10, 16),
                  lastDay: DateTime.utc(2030, 3, 14),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    }
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  eventLoader: _getEventsForDay,
                  calendarStyle: const CalendarStyle(
                    defaultTextStyle: TextStyle(color: Colors.white),
                    weekendTextStyle: TextStyle(color: Colors.redAccent),
                    outsideTextStyle: TextStyle(color: Colors.grey),
                    selectedDecoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    titleTextStyle: TextStyle(color: Colors.red, fontSize: 20),
                    formatButtonTextStyle: TextStyle(color: Colors.red),
                    leftChevronIcon: Icon(Icons.chevron_left, color: Colors.red),
                    rightChevronIcon: Icon(Icons.chevron_right, color: Colors.red),
                  ),
                ),
                const SizedBox(height: 8.0),
                Expanded(
                  child: ListView.builder(
                    itemCount: _getEventsForDay(_selectedDay!).length,
                    itemBuilder: (context, index) {
                      final event = _getEventsForDay(_selectedDay!)[index];
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(
                            event['title'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            event['description'] ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: Icon(
                            Icons.circle,
                            color: event['status'] == 'DONE' ? Colors.green : Colors.red,
                            size: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
