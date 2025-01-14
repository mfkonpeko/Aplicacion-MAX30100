import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MeasurementsScreen(), // Pantalla de Mediciones
    const BluetoothScreen(),
    const AdviceScreen(),
    const EmergencyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'Mediciones',
            backgroundColor: Colors.blue,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'Bluetooth',
            backgroundColor: Colors.green,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Consejos',
            backgroundColor: Color.fromARGB(255, 226, 150, 175),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Emergencia',
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );
  }
}

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final _bluetooth = FlutterBluetoothSerial.instance;
  bool _bluetoothState = false;
  List<BluetoothDevice> _devices = [];

  void _getDevices() async {
    var res = await _bluetooth.getBondedDevices();
    setState(() => _devices = res);
  }

  void _requestPermission() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  @override
  void initState() {
    super.initState();

    _requestPermission();

    _bluetooth.state.then((state) {
      setState(() => _bluetoothState = state.isEnabled);
    });

    _bluetooth.onStateChanged().listen((state) {
      setState(() => _bluetoothState = state.isEnabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth'),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 189, 243, 207),
      ),
      body: Container(
        // Cambiar el color de fondo aquí
        color: Color.fromARGB(
            255, 189, 243, 207), // Cambia este color según tus preferencias
        child: Column(
          children: [
            _controlBT(),
            Expanded(child: _listDevices()),
          ],
        ),
      ),
    );
  }

  Widget _controlBT() {
    return SwitchListTile(
      value: _bluetoothState,
      onChanged: (bool value) async {
        if (value) {
          await _bluetooth.requestEnable();
        } else {
          await _bluetooth.requestDisable();
        }
      },
      title: Text(
        _bluetoothState ? "Bluetooth encendido" : "Bluetooth apagado",
      ),
    );
  }

  Widget _listDevices() {
    return ListView(
      children: [
        for (final device in _devices)
          ListTile(
            title: Text(device.name ?? device.address),
          )
      ],
    );
  }
}

class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  BluetoothConnection? _connection;
  bool isConnecting = true;
  bool isConnected = false;

  String spo2 = "0%";
  String heartRate = "0 bpm";

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  Future<void> _connectToDevice() async {
    // Replace 'XX:XX:XX:XX:XX:XX' with the address of your HC-05 module
    final String hc05Address = "00:22:04:00:A6:B1";

    try {
      BluetoothConnection connection =
          await BluetoothConnection.toAddress(hc05Address);
      setState(() {
        _connection = connection;
        isConnecting = false;
        isConnected = true;
      });

      connection.input!.listen((data) {
        String received = String.fromCharCodes(data).trim();

        // Assuming the data format from Arduino is 'spo2:95,hr:72'
        final parts = received.split(",");
        for (var part in parts) {
          if (part.startsWith("spo2:")) {
            setState(() {
              spo2 = part.split(":")[1] + "%"; // Extract SpO2 value
            });
          } else if (part.startsWith("hr:")) {
            setState(() {
              heartRate = part.split(":")[1] + " bpm"; // Extract Heart Rate
            });
          }
        }
      }).onDone(() {
        setState(() {
          isConnected = false; // Connection closed
        });
      });
    } catch (error) {
      print("Error: Unable to connect: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 174, 202, 243),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isConnected)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildCircularIndicator(
                      title: 'SpO2',
                      value: spo2,
                      minValue: 0,
                      maxValue: 100,
                      color: Colors.green,
                      icon: Icons.favorite,
                    ),
                    const SizedBox(height: 32),
                    buildCircularIndicator(
                      title: 'Frecuencia cardiaca',
                      value: heartRate,
                      minValue: 0,
                      maxValue: 180,
                      color: Colors.purple,
                      icon: Icons.favorite,
                    ),
                  ],
                ),
              ),
            )
          else
            const Expanded(
              // Usar Expanded para centrar el texto
              child: Center(
                child: Text(
                  "Conectando al dispositivo...",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }

  Widget buildCircularIndicator({
    required String title,
    required String value,
    required int minValue,
    required int maxValue,
    required Color color,
    required IconData icon,
  }) {
    String numericValue =
        value.replaceAll(RegExp(r'[^0-9.]'), ''); // Extract number
    double progress = 0.0;

    if (numericValue.isNotEmpty) {
      double? parsedValue = double.tryParse(numericValue);
      if (parsedValue != null) {
        progress = (parsedValue - minValue) / (maxValue - minValue);
      }
    }

    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 150,
              width: 150,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                color: color,
                backgroundColor: color.withAlpha(51),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$minValue'),
            Text('$maxValue'),
          ],
        ),
      ],
    );
  }
}

class AdviceScreen extends StatelessWidget {
  const AdviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 218, 182, 194),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 226, 150, 175),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Consejos:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 78, 76, 76),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Si usted cree que alguien está teniendo un ataque cardíaco, haga lo siguiente:',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 78, 76, 76),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                '- Procure que la persona se siente, descanse y trate de mantener la calma.\n'
                '- Afloje cualquier prenda de vestir ajustada.\n'
                '- Pregúntele si toma medicamentos para el dolor torácico, como nitroglicerina por una enfermedad cardíaca conocida y ayúdele a tomarlos.\n'
                '- Si la persona está inconsciente y no reacciona y no respira o no tiene pulso, llame al 911 o al número local de emergencias, luego inicie la RCP.\n'
                '- Si un bebé o un niño está inconsciente y no reacciona y no respira o no tiene pulso, administre la RCP durante 1 minuto, luego llame al 911 o al número local de emergencias.\n'
                '- Si la persona está inconsciente y no responde, no tiene pulso y hay un desfibrilador externo automático (DEA) disponible de inmediato, siga las instrucciones del dispositivo DEA',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '¿Cómo prevenir ataques cardiacos?',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 78, 76, 76),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                '- Si usted fuma, deje de hacerlo. El tabaquismo aumenta a más del doble la probabilidad de padecer una enfermedad cardíaca.\n'
                '- Mantenga un buen control de la presión arterial, el colesterol y la diabetes, y acate las órdenes de su proveedor de atención médica.\n'
                '- Baje de peso si está obeso o con sobrepeso.\n'
                '- Haga ejercicio de manera regular para mejorar su salud.\n'
                '- Consuma una dieta saludable para el corazón. Limite las grasas saturadas, las carnes rojas y los azúcares. Incremente la ingesta de pollo, pescado, frutas y verduras frescas, al igual que de granos enteros.\n'
                '- Limite la cantidad de alcohol que consume. Un trago al día está asociado con la reducción de la tasa de ataques cardíacos, pero tomar dos o más tragos al día puede causar daño al corazón y ocasionar otros problemas de salud.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdviceCard(
      {required String title, required String description}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.yellow[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.yellow[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.brown[800],
            ),
          ),
        ],
      ),
    );
  }
}

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[100],
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.red[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Números de emergencia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[100],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Emergencias: 911',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cruz Roja: 55 53 95 11 11',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
