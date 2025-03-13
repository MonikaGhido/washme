import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

void main(){
  runApp(const MyApp());
}

// String formatDate(String date) {
//   DateTime parsedDate = DateTime.parse(date);
//   return DateFormat('EEEE d MMMM', 'it').format(parsedDate);
// }

String formatDate(String date) {
  DateTime parsedDate = DateTime.parse(date);

  // Mappa per convertire i giorni della settimana in italiano
  List<String> giorniSettimana = [
    "Domenica", "Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato"
  ];

  // Mappa per convertire i mesi in italiano
  List<String> mesi = [
    "Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno",
    "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"
  ];

  String giornoSettimana = giorniSettimana[parsedDate.weekday % 7];
  String mese = mesi[parsedDate.month - 1];
  String giorno = parsedDate.day.toString();

  return "$giornoSettimana $giorno $mese";
}


Future<Map<String, dynamic>> getWeatherCodeDescriptions() async {
  final String response = await rootBundle.loadString('assets/weather_codes.json');
  final Map<String, dynamic> jsonData = jsonDecode(response);
  return jsonData;
}

Future<Map<String, double>> getCoordinates(String city) async {
  final url = 'https://nominatim.openstreetmap.org/search?city=$city&format=json';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    if (data.isNotEmpty) {
      return {
        'latitude': double.parse(data[0]['lat']),
        'longitude': double.parse(data[0]['lon'])
      };
    }
  }
  throw Exception('Errore nel recupero delle coordinate per $city');
}

Future<Map<String, dynamic>> getWeatherData(String city) async {
  final coords = await getCoordinates(city);
  final url = 'https://api.open-meteo.com/v1/forecast?latitude=${coords['latitude']}&longitude=${coords['longitude']}&daily=rain_sum,precipitation_probability_max,weather_code&timezone=auto&forecast_days=14';

  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Errore caricamento dati meteo');
  }
}

Future<Map<String, dynamic>> confrontaLocalita(String city1, String city2) async {
  final datiCitta1 = await getWeatherData(city1);
  final datiCitta2 = await getWeatherData(city2);

  final giorni = datiCitta1['daily']['time'].map<String>((date) => formatDate(date)).toList();
  final pioggiaCitta1 = datiCitta1['daily']['precipitation_probability_max'];
  final pioggiaCitta2 = datiCitta2['daily']['precipitation_probability_max'];
  final weatherCodes = datiCitta1['daily']['weather_code'];

  String giornoMigliore = '';
  double punteggioMigliore = double.infinity;
  int bestIndex = 0;

  for (int i = 0; i < giorni.length - 5; i++) {
    double sommaPioggia = 0.0;
    for (int j = i; j <= i + 5; j++) {
      sommaPioggia += pioggiaCitta1[j] + pioggiaCitta2[j];
    }

    double mediaPioggia = sommaPioggia / 12;

    if (mediaPioggia < punteggioMigliore) {
      punteggioMigliore = mediaPioggia;
      giornoMigliore = giorni[i];
      bestIndex = i;
    }
  }

  bool troppaPioggia = false;
  for (int i = bestIndex; i < bestIndex + 6 && i < giorni.length; i++) {
    if (pioggiaCitta1[i] > 40 || pioggiaCitta2[i] > 40) {
      troppaPioggia = true;
      break;
    }
  }

  return {
    'giornoMigliore': giornoMigliore,
    'previsioni': giorni,
    'weatherCodes': weatherCodes,
    'pioggiaCitta1': pioggiaCitta1,
    'troppaPioggia': troppaPioggia,
    'primaCitta': city1,
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WashMe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('WashMe 🌦️', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder(
        future: Future.wait([
          confrontaLocalita('Casalbuttano ed Uniti', 'Trescore Balneario'),
          getWeatherCodeDescriptions(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('😵 Errore: ${snapshot.error}'));
          }

          final data = snapshot.data![0];
          final bestDay = data['giornoMigliore'];
          final giorni = data['previsioni'];
          final troppaPioggia = data['troppaPioggia'];
          final primaCitta = data['primaCitta'];
          final weatherCodes = data['weatherCodes'];
          final precipitation = data['pioggiaCitta1'];
          final weatherDescriptions = snapshot.data![1];

          return Column(
            children: [
              const SizedBox(height: 30),
              Card(
                elevation: 4,
                color: Colors.blue.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_car_wash, size: 60, color: Colors.blue),
                      const SizedBox(height: 10),
                      const Text('Giorno ideale per lavare la macchina:',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 10),
                      Text(bestDay,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      if (troppaPioggia)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            '💦 Attenzione! Forse è meglio aspettare, sembra che pioverà troppo!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                     ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Meteo $primaCitta:', textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: giorni.length,
                  itemBuilder: (context, index) {
                    String code = weatherCodes[index].toString();
                    String description = weatherDescriptions[code]['day']['description'] ?? "Dato non disponibile";
                    String iconUrl = weatherDescriptions[code]['day']['image'] ?? "";
                    return ListTile(
                      leading: iconUrl.isNotEmpty ? Image.network(iconUrl) : const Icon(Icons.wb_cloudy),
                      title: Text(giorni[index],
                          style: TextStyle(fontWeight: giorni[index] == bestDay ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text('$description, 🌧️ ${precipitation[index]}%'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
