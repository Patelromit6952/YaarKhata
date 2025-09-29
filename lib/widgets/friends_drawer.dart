import 'package:flutter/material.dart';
import 'package:friendsbook/AboutUsPage.dart';
import 'package:friendsbook/PrivacyPolicyPage.dart';
import '../dataservice.dart';

class FriendsDrawer extends StatelessWidget {
  final DataService dataService;
  final VoidCallback onLogout;

  const FriendsDrawer({
    Key? key,
    required this.dataService,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: 2,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade500, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    '👤',
                    style: TextStyle(fontSize: 30),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  dataService.currentUserName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '+91 ${dataService.currentUserPhone}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.info_outline, color: Colors.blue.shade700),
            title: Text(
              'About Us',
              style: TextStyle(color: Colors.blue.shade900, fontSize: 16),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AboutUsPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.lock_outline, color: Colors.blue.shade700),
            title: Text(
              'Privacy Policy',
              style: TextStyle(color: Colors.blue.shade900, fontSize: 16),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrivacyPolicyPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade600),
            title: Text(
              'Logout',
              style: TextStyle(color: Colors.red.shade700, fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
        ],
      ),
    );
  }
}