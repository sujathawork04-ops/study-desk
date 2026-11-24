// Boards, grade names, languages and school years, by country — the same data
// as lib/curricula.ts in the web app, so a child set up on one shows up
// correctly on the other.

class Board {
  const Board(this.id, this.name, {this.short, this.note, required this.grades});
  final String id, name;
  final String? short, note;
  final List<String> grades;
}

class Country {
  const Country(this.code, this.name, this.boards);
  final String code, name;
  final List<Board> boards;
}

List<String> _seq(String label, int from, int to, [List<String> extra = const []]) =>
    [...extra, for (var i = from; i <= to; i++) "$label $i"];

const _kg = ["Nursery", "LKG", "UKG"];
const _kinder = ["Pre-K", "Kindergarten"];

/// Offered inside every country as well as on their own.
final _international = <Board>[
  Board("ib", "International Baccalaureate (IB)", short: "IB",
      note: "PYP (1–5), MYP (6–10), DP (11–12)", grades: _seq("Grade", 1, 12, ["PYP Early Years"])),
  Board("cambridge", "Cambridge International (CAIE)", short: "Cambridge",
      grades: _seq("Year", 1, 13, _kinder)),
  Board("american", "American curriculum", short: "US curriculum",
      grades: _seq("Grade", 1, 12, _kinder)),
  Board("homeschool", "Home schooling / other", short: "home school",
      grades: _seq("Year", 1, 12, _kinder)),
];

final List<Country> countries = () {
  final list = <Country>[
    Country("IN", "India", [
      Board("cbse", "CBSE", short: "CBSE", grades: _seq("Class", 1, 12, _kg)),
      Board("icse", "ICSE / ISC (CISCE)", short: "ICSE", grades: _seq("Class", 1, 12, _kg)),
      Board("tn", "Tamil Nadu State Board", short: "TN State Board", grades: _seq("Class", 1, 12, _kg)),
      Board("ker", "Kerala State Board", short: "Kerala Board", grades: _seq("Class", 1, 12, _kg)),
      Board("kar", "Karnataka State Board", short: "Karnataka Board", grades: _seq("Class", 1, 12, _kg)),
      Board("ap", "Andhra Pradesh / Telangana Board", short: "AP/TS Board", grades: _seq("Class", 1, 12, _kg)),
      Board("mah", "Maharashtra State Board", short: "Maharashtra Board", grades: _seq("Class", 1, 12, _kg)),
      Board("wb", "West Bengal Board", short: "WB Board", grades: _seq("Class", 1, 12, _kg)),
      Board("up", "UP Board", short: "UP Board", grades: _seq("Class", 1, 12, _kg)),
      Board("guj", "Gujarat State Board", short: "Gujarat Board", grades: _seq("Class", 1, 12, _kg)),
      Board("nios", "NIOS (open schooling)", short: "NIOS", grades: _seq("Class", 3, 12)),
    ]),
    Country("PK", "Pakistan", [
      Board("pk-fed", "Federal Board / Matric", short: "Matric", grades: _seq("Class", 1, 12, _kg)),
    ]),
    Country("BD", "Bangladesh", [
      Board("bd-nctb", "NCTB (national)", short: "NCTB", grades: _seq("Class", 1, 12, _kg)),
    ]),
    Country("LK", "Sri Lanka", [
      Board("lk-nie", "National (NIE)", short: "National", grades: _seq("Grade", 1, 13)),
    ]),
    Country("NP", "Nepal", [
      Board("np-neb", "National (NEB)", short: "NEB", grades: _seq("Class", 1, 12)),
    ]),
    Country("US", "United States", [
      Board("us-common", "State standards", short: "US", grades: _seq("Grade", 1, 12, _kinder)),
    ]),
    Country("CA", "Canada", [
      Board("ca-prov", "Provincial curriculum", short: "Canada", grades: _seq("Grade", 1, 12, _kinder)),
      Board("ca-qc", "Québec", short: "Québec", grades: [..._seq("Primary", 1, 6), ..._seq("Secondary", 1, 5)]),
    ]),
    Country("GB", "United Kingdom", [
      Board("gb-eng", "England & Wales (National Curriculum)", short: "National Curriculum",
          grades: _seq("Year", 1, 13, ["Reception"])),
      Board("gb-sco", "Scotland (CfE)", short: "CfE", grades: [..._seq("P", 1, 7), ..._seq("S", 1, 6)]),
    ]),
    Country("IE", "Ireland", [
      Board("ie-nat", "National curriculum", short: "Ireland",
          grades: ["Junior Infants", "Senior Infants", ..._seq("Class", 1, 6), ..._seq("Year", 1, 6)]),
    ]),
    Country("AU", "Australia", [
      Board("au-nat", "Australian Curriculum", short: "Australia", grades: _seq("Year", 1, 12, ["Foundation"])),
    ]),
    Country("NZ", "New Zealand", [
      Board("nz-nat", "New Zealand Curriculum", short: "NZ", grades: _seq("Year", 1, 13)),
    ]),
    Country("SG", "Singapore", [
      Board("sg-moe", "MOE syllabus", short: "MOE",
          grades: [..._seq("Primary", 1, 6), ..._seq("Secondary", 1, 5), "JC 1", "JC 2"]),
    ]),
    Country("MY", "Malaysia", [
      Board("my-kssr", "KSSR / KSSM", short: "KSSR",
          grades: [..._seq("Tahun", 1, 6), ..._seq("Tingkatan", 1, 5)]),
    ]),
    Country("AE", "United Arab Emirates", [
      Board("ae-moe", "UAE MOE curriculum", short: "UAE MOE", grades: _seq("Grade", 1, 12, _kinder)),
    ]),
    Country("SA", "Saudi Arabia", [
      Board("sa-moe", "Saudi national curriculum", short: "Saudi MOE", grades: _seq("Grade", 1, 12)),
    ]),
    Country("QA", "Qatar", [
      Board("qa-moe", "Qatar national curriculum", short: "Qatar MOE", grades: _seq("Grade", 1, 12)),
    ]),
    Country("ZA", "South Africa", [
      Board("za-caps", "CAPS", short: "CAPS", grades: _seq("Grade", 1, 12, ["Grade R"])),
    ]),
    Country("KE", "Kenya", [
      Board("ke-cbc", "Competency Based Curriculum", short: "CBC",
          grades: [..._seq("Grade", 1, 9), ..._seq("Form", 1, 4)]),
      Board("ke-844", "8-4-4 (older system)", short: "8-4-4",
          grades: [..._seq("Standard", 1, 8), ..._seq("Form", 1, 4)]),
    ]),
    Country("NG", "Nigeria", [
      Board("ng-nerdc", "NERDC national curriculum", short: "NERDC",
          grades: [..._seq("Primary", 1, 6), ..._seq("JSS", 1, 3), ..._seq("SSS", 1, 3)]),
    ]),
    Country("GH", "Ghana", [
      Board("gh-nacca", "NaCCA curriculum", short: "NaCCA",
          grades: [..._seq("Basic", 1, 9), ..._seq("SHS", 1, 3)]),
    ]),
    Country("TZ", "Tanzania", [
      Board("tz-tie", "TIE curriculum", short: "TIE",
          grades: [..._seq("Standard", 1, 7), ..._seq("Form", 1, 6)]),
    ]),
    Country("EG", "Egypt", [
      Board("eg-moe", "Egyptian national curriculum", short: "Egypt MOE", grades: _seq("Grade", 1, 12)),
    ]),
    Country("PH", "Philippines", [
      Board("ph-k12", "K to 12", short: "K-12", grades: _seq("Grade", 1, 12, ["Kindergarten"])),
    ]),
    Country("ID", "Indonesia", [
      Board("id-merdeka", "Kurikulum Merdeka", short: "Merdeka",
          grades: [..._seq("SD", 1, 6), ..._seq("SMP", 1, 3), ..._seq("SMA", 1, 3)]),
    ]),
    Country("VN", "Vietnam", [
      Board("vn-moet", "MOET curriculum", short: "MOET", grades: _seq("Lớp", 1, 12)),
    ]),
    Country("TH", "Thailand", [
      Board("th-obec", "Basic Education Core Curriculum", short: "OBEC",
          grades: [..._seq("Prathom", 1, 6), ..._seq("Mathayom", 1, 6)]),
    ]),
    Country("JP", "Japan", [
      Board("jp-moe", "MEXT curriculum", short: "MEXT",
          grades: [..._seq("Elementary", 1, 6), ..._seq("Junior high", 1, 3), ..._seq("High school", 1, 3)]),
    ]),
    Country("KR", "South Korea", [
      Board("kr-moe", "National curriculum", short: "Korea",
          grades: [..._seq("Elementary", 1, 6), ..._seq("Middle", 1, 3), ..._seq("High", 1, 3)]),
    ]),
    Country("CN", "China", [
      Board("cn-moe", "National curriculum", short: "China", grades: _seq("Grade", 1, 12)),
    ]),
    Country("DE", "Germany", [
      Board("de-land", "Länder curriculum", short: "Germany", grades: _seq("Klasse", 1, 13)),
    ]),
    const Country("FR", "France", [
      Board("fr-nat", "Éducation nationale", short: "France",
          grades: ["CP", "CE1", "CE2", "CM1", "CM2", "6e", "5e", "4e", "3e", "2nde", "1re", "Terminale"]),
    ]),
    Country("ES", "Spain", [
      Board("es-loe", "Currículo nacional", short: "Spain",
          grades: [..._seq("Primaria", 1, 6), ..._seq("ESO", 1, 4), ..._seq("Bachillerato", 1, 2)]),
    ]),
    Country("IT", "Italy", [
      Board("it-miur", "Indicazioni nazionali", short: "Italy",
          grades: [..._seq("Primaria", 1, 5), ..._seq("Media", 1, 3), ..._seq("Superiore", 1, 5)]),
    ]),
    Country("NL", "Netherlands", [
      Board("nl-nat", "Nederlands curriculum", short: "Netherlands", grades: _seq("Groep", 1, 8)),
    ]),
    Country("BR", "Brazil", [
      Board("br-bncc", "BNCC", short: "BNCC", grades: _seq("Ano", 1, 12)),
    ]),
    Country("MX", "Mexico", [
      Board("mx-sep", "SEP", short: "SEP",
          grades: [..._seq("Primaria", 1, 6), ..._seq("Secundaria", 1, 3), ..._seq("Bachillerato", 1, 3)]),
    ]),
    Country("TR", "Türkiye", [
      Board("tr-meb", "MEB müfredatı", short: "MEB", grades: _seq("Sınıf", 1, 12)),
    ]),
    Country("RU", "Russia", [
      Board("ru-fgos", "ФГОС (FGOS)", short: "FGOS", grades: _seq("Класс", 1, 11)),
    ]),
    Country("XX", "Somewhere else / international", _international),
  ];

  // International boards are offered inside every country too.
  return [
    for (final c in list)
      c.code == "XX" ? c : Country(c.code, c.name, [...c.boards, ..._international])
  ];
}();

Country? findCountry(String code) {
  for (final c in countries) {
    if (c.code == code) return c;
  }
  return null;
}

Board? findBoard(String countryCode, String boardId) {
  for (final b in findCountry(countryCode)?.boards ?? const <Board>[]) {
    if (b.id == boardId) return b;
  }
  return null;
}

/// What the tutor is told: "Class 4 (CBSE, India)".
String describeGrade(String countryCode, String boardId, String grade) {
  final c = findCountry(countryCode);
  final b = findBoard(countryCode, boardId);
  final board = b?.short ?? b?.name ?? boardId;
  return (c != null && c.code != "XX") ? "$grade ($board, ${c.name})" : "$grade ($board)";
}

/// The board in full, for the tutor: its name as the school would write it,
/// the country, and any note the app keeps about how it is structured.
String describeBoard(String countryCode, String boardId) {
  final c = findCountry(countryCode);
  final b = findBoard(countryCode, boardId);
  if (b == null) return boardId;

  final name = b.name == (b.short ?? b.name) ? b.name : "${b.short} (${b.name})";
  final where = (c != null && c.code != "XX") ? ", ${c.name}" : "";
  return "$name$where${b.note == null ? "" : " — ${b.note}"}";
}

/// Rough age for a grade — helps the tutor pitch its language.
int? approxAge(String grade) {
  final m = RegExp(r"\d+").firstMatch(grade);
  if (m == null) return null;
  final n = int.parse(m.group(0)!);
  final g = grade.toLowerCase();
  if (RegExp(r"prim|standard|class|grade|ano|sınıf|klasse|groep|elementary|sd\b").hasMatch(g) && n <= 8) {
    return n + 5;
  }
  if (g.contains("year")) return n + 4;
  if (RegExp(r"secondary|form|jss|sss|middle|high|smp|sma|mathayom").hasMatch(g)) return n + 11;
  return n <= 13 ? n + 5 : null;
}

const languages = [
  "English", "Hindi", "Tamil", "Telugu", "Kannada", "Malayalam", "Marathi", "Bengali",
  "Gujarati", "Punjabi", "Urdu", "Sanskrit", "Sinhala", "Nepali", "Arabic", "French",
  "Spanish", "German", "Mandarin", "Japanese", "Korean", "Bahasa Malaysia",
  "Bahasa Indonesia", "Thai", "Vietnamese", "Filipino", "Swahili", "Afrikaans",
  "isiZulu", "Yoruba", "Portuguese", "Italian", "Dutch", "Turkish", "Russian", "Other",
];

const commonSubjects = [
  "Maths", "English", "Science", "EVS", "Social", "Social Studies", "History", "Geography",
  "Computer", "General Knowledge", "Moral Science", "Art", "Craft", "Music",
  "Physical Education", "Hindi", "Tamil", "Telugu", "Kannada", "Malayalam", "Marathi",
  "Bengali", "Gujarati", "Sanskrit", "Urdu", "French", "German", "Spanish",
];

// ------------------------------------------------------------- academic year
typedef AcademicYear = ({int startMonth, String label});

const academicYears = <String, AcademicYear>{
  "IN": (startMonth: 4, label: "April – March"),
  "PK": (startMonth: 4, label: "April – March"),
  "BD": (startMonth: 1, label: "January – December"),
  "LK": (startMonth: 1, label: "January – December"),
  "NP": (startMonth: 4, label: "April – March"),
  "US": (startMonth: 8, label: "August – May/June"),
  "CA": (startMonth: 9, label: "September – June"),
  "GB": (startMonth: 9, label: "September – July"),
  "IE": (startMonth: 9, label: "September – June"),
  "AU": (startMonth: 1, label: "January – December"),
  "NZ": (startMonth: 2, label: "February – December"),
  "SG": (startMonth: 1, label: "January – November"),
  "MY": (startMonth: 3, label: "March – December"),
  "AE": (startMonth: 9, label: "September – June"),
  "SA": (startMonth: 8, label: "August – June"),
  "QA": (startMonth: 9, label: "September – June"),
  "ZA": (startMonth: 1, label: "January – December"),
  "KE": (startMonth: 1, label: "January – November"),
  "NG": (startMonth: 9, label: "September – July"),
  "GH": (startMonth: 9, label: "September – July"),
  "TZ": (startMonth: 1, label: "January – December"),
  "EG": (startMonth: 9, label: "September – June"),
  "PH": (startMonth: 8, label: "August – May"),
  "ID": (startMonth: 7, label: "July – June"),
  "VN": (startMonth: 9, label: "September – May"),
  "TH": (startMonth: 5, label: "May – March"),
  "JP": (startMonth: 4, label: "April – March"),
  "KR": (startMonth: 3, label: "March – February"),
  "CN": (startMonth: 9, label: "September – July"),
  "DE": (startMonth: 9, label: "August/September – July"),
  "FR": (startMonth: 9, label: "September – July"),
  "ES": (startMonth: 9, label: "September – June"),
  "IT": (startMonth: 9, label: "September – June"),
  "NL": (startMonth: 9, label: "September – July"),
  "BR": (startMonth: 2, label: "February – December"),
  "MX": (startMonth: 8, label: "August – July"),
  "TR": (startMonth: 9, label: "September – June"),
  "RU": (startMonth: 9, label: "September – May"),
  "XX": (startMonth: 9, label: "September – June"),
};

const academicYearOptions = <AcademicYear>[
  (startMonth: 1, label: "January – December"),
  (startMonth: 2, label: "February – December"),
  (startMonth: 3, label: "March – February"),
  (startMonth: 4, label: "April – March"),
  (startMonth: 5, label: "May – March"),
  (startMonth: 6, label: "June – April"),
  (startMonth: 7, label: "July – June"),
  (startMonth: 8, label: "August – May/June"),
  (startMonth: 9, label: "September – July"),
  (startMonth: 10, label: "October – July"),
];

AcademicYear academicYearFor(String country) =>
    academicYears[country] ?? academicYears["XX"]!;

/// "2026–27", or "2026" when the year sits inside one calendar year.
String academicYearLabel(int startMonth, {DateTime? today}) {
  final t = today ?? DateTime.now();
  final startYear = t.month >= startMonth ? t.year : t.year - 1;
  if (startMonth == 1) return "$startYear";
  return "$startYear–${(startYear + 1).toString().substring(2)}";
}

/// How far into the school year she is — the tutor uses this to pace revision.
String academicYearPart(int startMonth, {DateTime? today}) {
  final t = today ?? DateTime.now();
  final monthsIn = ((t.month - startMonth) + 12) % 12;
  if (monthsIn <= 2) return "beginning of the school year";
  if (monthsIn <= 6) return "middle of the school year";
  if (monthsIn <= 9) return "later part of the school year";
  return "end of the school year (exam season for many schools)";
}
