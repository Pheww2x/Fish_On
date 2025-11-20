import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  final String userRole;
  const TutorialScreen({super.key, required this.userRole});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _step = 0;

  List<Map<String, dynamic>> get _steps => widget.userRole == 'fisherman' ? [
    {'title': 'Welcome!', 'desc': 'Let me show you around the Fisherman Dashboard'},
    {'title': 'Help Button', 'desc': 'Tap the ? icon anytime to see this tutorial again'},
    {'title': 'Logout', 'desc': 'Tap the logout icon to sign out of your account'},
    {'title': 'Profile Photo', 'desc': 'Your profile picture - tap Edit Profile to change it'},
    {'title': 'Map Visibility', 'desc': 'Toggle this switch to show/hide yourself on the buyer map'},
    {'title': 'Edit Profile', 'desc': 'Update your photo, contact info, and location'},
    {'title': 'Messages', 'desc': 'Chat with buyers about your fish'},
    {'title': 'Add Fish', 'desc': 'Create new fish listings to sell'},
    {'title': 'Manage Listings', 'desc': 'Edit or delete your existing fish listings'},
  ] : [
    {'title': 'Welcome!', 'desc': 'Let me show you around the Buyer Map'},
    {'title': 'Logout', 'desc': 'Tap the red icon to sign out of your account'},
    {'title': 'Tutorial', 'desc': 'Tap the orange ? icon to see this guide again'},
    {'title': 'Search', 'desc': 'Tap the search icon to find specific fish or fishermen'},
    {'title': 'Location Info', 'desc': 'Shows your current location and available fishermen count'},
    {'title': 'Fisherman Markers', 'desc': 'Green markers with photos show fishermen locations'},
    {'title': 'Your Location', 'desc': 'The blue marker shows where you are'},
    {'title': 'Tap Markers', 'desc': 'Tap any fisherman marker to see their profile and fish listings'},
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 350),
                margin: EdgeInsets.all(20),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 50, color: Colors.amber),
                    SizedBox(height: 16),
                    Text(
                      step['title'],
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      step['desc'],
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_steps.length, (i) => Container(
                        margin: EdgeInsets.symmetric(horizontal: 3),
                        width: _step == i ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _step == i ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_step < _steps.length - 1) {
                            setState(() => _step++);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _step < _steps.length - 1 ? 'Next' : 'Got it!',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
