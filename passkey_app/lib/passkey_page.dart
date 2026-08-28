import 'package:flutter/material.dart';
import 'package:passkey_app/api.dart';
import 'package:passkey_app/passkey_service.dart';

class PasskeyPage extends StatefulWidget {
  const PasskeyPage({super.key});

  @override
  State<PasskeyPage> createState() => _PasskeyPageState();
}

class _PasskeyPageState extends State<PasskeyPage> {
  final usernameController = TextEditingController();
  final passkeyService = PasskeyService();

  String message = '';
  final List<String> logs = [];

  void addLog(String text) {
    setState(() {
      logs.insert(
        0,
        '${DateTime.now().toLocal()} - $text',
      );
    });
  }

  Future<void> register() async {
    final username = usernameController.text.trim();

    try {
      addLog('Starting registration for $username');

      final options = await Api.registerOptions(username);
      addLog('Registration options received');

      final credential =
          await passkeyService.createPasskey(options);
      addLog('Passkey created by Credential Manager');

      await Api.registerVerify(
        username,
        credential.toJson(),
      );

      setState(() {
        message = 'Registration successful';
      });

      addLog('Registration successful for $username');
    } catch (e) {
      setState(() {
        message = 'Registration failed';
      });

      addLog('Registration error: $e');
    }
  }

  Future<void> login() async {
    final username = usernameController.text.trim();

    try {
      addLog('Starting login for $username');

      final options = await Api.loginOptions(username);
      addLog('Login options received');

      final credential =
          await passkeyService.authenticate(options);
      addLog('Passkey retrieved by Credential Manager');

      await Api.loginVerify(
        credential.toJson(),
      );

      setState(() {
        message = 'Login successful';
      });

      addLog('Login successful for $username');
    } catch (e) {
      setState(() {
        message = 'Login failed';
      });

      addLog('Login error: $e');
    }
  }

  void showLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Logs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const Divider(),

              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text('No logs yet'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 8,
                            ),
                            child: Text(
                              logs[index],
                            ),
                          );
                        },
                      ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      logs.clear();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Clear logs'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passkey POC'),

        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logs') {
                showLogs();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logs',
                child: Text('Logs'),
              ),
            ],
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: register,
              child: const Text(
                'Register Passkey',
              ),
            ),

            ElevatedButton(
              onPressed: login,
              child: const Text(
                'Login with Passkey',
              ),
            ),

            const SizedBox(height: 24),

            Text(message),
          ],
        ),
      ),
    );
  }
}
