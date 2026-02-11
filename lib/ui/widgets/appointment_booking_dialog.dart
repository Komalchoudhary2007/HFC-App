import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';

class AppointmentBookingDialog extends StatefulWidget {
  const AppointmentBookingDialog({Key? key}) : super(key: key);

  @override
  State<AppointmentBookingDialog> createState() => _AppointmentBookingDialogState();
}

class _AppointmentBookingDialogState extends State<AppointmentBookingDialog> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  final List<String> _timeSlots = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
  ];

  String? _selectedTimeSlot;

  Future<void> _submitAppointment() async {
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      // Prepare appointment data
      final appointmentData = {
        'userId': user.id,
        'userName': user.name,
        'userPhone': user.phone,
        'appointmentDate': _selectedDay.toIso8601String().split('T')[0], // YYYY-MM-DD
        'appointmentTime': _selectedTimeSlot,
        'appointmentFlag': 'consultation_booking',
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Send to webhook (same endpoint as HC20 data)
      final dio = Dio();
      await dio.post(
        'https://api.hireforcare.com/webhook/hc20-data',
        data: appointmentData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500, // Accept all responses < 500
        ),
      );

      setState(() {
        _isSubmitting = false;
      });

      // Success - save values before closing dialog
      final selectedDate = '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}';
      final selectedTime = _selectedTimeSlot ?? '';
      
      // Close booking dialog first
      Navigator.of(context).pop();
      
      // Show confirmation dialog using the parent context
      if (mounted) {
        _showConfirmationDialogWithData(selectedDate, selectedTime);
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error booking appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfirmationDialogWithData(String selectedDate, String selectedTime) {
    // Use a slight delay to ensure the previous dialog is fully closed
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Text(
                'Appointment Booked!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF532A7B),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your consultation has been scheduled successfully.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFE7E2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20, color: Color(0xFF532A7B)),
                        const SizedBox(width: 8),
                        Text(
                          selectedDate,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 20, color: Color(0xFF532A7B)),
                        const SizedBox(width: 8),
                        Text(
                          selectedTime,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Our team will contact you shortly to confirm.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Color(0xFF532A7B),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    });
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Text(
              'Appointment Booked!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF532A7B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your consultation has been scheduled successfully.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFE7E2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: Color(0xFF532A7B)),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 20, color: Color(0xFF532A7B)),
                      const SizedBox(width: 8),
                      Text(
                        _selectedTimeSlot ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Our team will contact you shortly to confirm.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFF532A7B),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Book Consultation',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF532A7B),
                        fontFamily: 'poppins',
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Calendar
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.now(),
                    lastDay: DateTime.now().add(Duration(days: 60)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF532A7B),
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: Color(0xFF532A7B),
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Color(0xFF532A7B).withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: TextStyle(color: Colors.red),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Time Slots
                Text(
                  'Select Time Slot',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _timeSlots.map((slot) {
                    final isSelected = _selectedTimeSlot == slot;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTimeSlot = slot;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Color(0xFF532A7B) : Colors.white,
                          border: Border.all(
                            color: isSelected ? Color(0xFF532A7B) : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slot,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF532A7B),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Book Appointment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
