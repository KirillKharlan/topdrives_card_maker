/// One country: its ISO 3166-1 alpha-2 code and English name.
class IsoCountry {
  const IsoCountry(this.code, this.name);

  final String code;
  final String name;
}

/// All ISO 3166-1 alpha-2 codes (249) plus XK for Kosovo, which is not an ISO
/// code but is used everywhere. Names are the usual short English ones.
/// The flag of every code is the picture assets/flags/<code in lower case>.png.
class IsoCountries {
  IsoCountries._();

  static const List<IsoCountry> all = [
    IsoCountry('AD', 'Andorra'),
    IsoCountry('AE', 'United Arab Emirates'),
    IsoCountry('AF', 'Afghanistan'),
    IsoCountry('AG', 'Antigua and Barbuda'),
    IsoCountry('AI', 'Anguilla'),
    IsoCountry('AL', 'Albania'),
    IsoCountry('AM', 'Armenia'),
    IsoCountry('AO', 'Angola'),
    IsoCountry('AQ', 'Antarctica'),
    IsoCountry('AR', 'Argentina'),
    IsoCountry('AS', 'American Samoa'),
    IsoCountry('AT', 'Austria'),
    IsoCountry('AU', 'Australia'),
    IsoCountry('AW', 'Aruba'),
    IsoCountry('AX', 'Åland Islands'),
    IsoCountry('AZ', 'Azerbaijan'),
    IsoCountry('BA', 'Bosnia and Herzegovina'),
    IsoCountry('BB', 'Barbados'),
    IsoCountry('BD', 'Bangladesh'),
    IsoCountry('BE', 'Belgium'),
    IsoCountry('BF', 'Burkina Faso'),
    IsoCountry('BG', 'Bulgaria'),
    IsoCountry('BH', 'Bahrain'),
    IsoCountry('BI', 'Burundi'),
    IsoCountry('BJ', 'Benin'),
    IsoCountry('BL', 'Saint Barthélemy'),
    IsoCountry('BM', 'Bermuda'),
    IsoCountry('BN', 'Brunei'),
    IsoCountry('BO', 'Bolivia'),
    IsoCountry('BQ', 'Caribbean Netherlands'),
    IsoCountry('BR', 'Brazil'),
    IsoCountry('BS', 'Bahamas'),
    IsoCountry('BT', 'Bhutan'),
    IsoCountry('BV', 'Bouvet Island'),
    IsoCountry('BW', 'Botswana'),
    IsoCountry('BY', 'Belarus'),
    IsoCountry('BZ', 'Belize'),
    IsoCountry('CA', 'Canada'),
    IsoCountry('CC', 'Cocos (Keeling) Islands'),
    IsoCountry('CD', 'Congo (DR)'),
    IsoCountry('CF', 'Central African Republic'),
    IsoCountry('CG', 'Congo (Republic)'),
    IsoCountry('CH', 'Switzerland'),
    IsoCountry('CI', 'Côte d’Ivoire'),
    IsoCountry('CK', 'Cook Islands'),
    IsoCountry('CL', 'Chile'),
    IsoCountry('CM', 'Cameroon'),
    IsoCountry('CN', 'China'),
    IsoCountry('CO', 'Colombia'),
    IsoCountry('CR', 'Costa Rica'),
    IsoCountry('CU', 'Cuba'),
    IsoCountry('CV', 'Cape Verde'),
    IsoCountry('CW', 'Curaçao'),
    IsoCountry('CX', 'Christmas Island'),
    IsoCountry('CY', 'Cyprus'),
    IsoCountry('CZ', 'Czechia'),
    IsoCountry('DE', 'Germany'),
    IsoCountry('DJ', 'Djibouti'),
    IsoCountry('DK', 'Denmark'),
    IsoCountry('DM', 'Dominica'),
    IsoCountry('DO', 'Dominican Republic'),
    IsoCountry('DZ', 'Algeria'),
    IsoCountry('EC', 'Ecuador'),
    IsoCountry('EE', 'Estonia'),
    IsoCountry('EG', 'Egypt'),
    IsoCountry('EH', 'Western Sahara'),
    IsoCountry('ER', 'Eritrea'),
    IsoCountry('ES', 'Spain'),
    IsoCountry('ET', 'Ethiopia'),
    IsoCountry('FI', 'Finland'),
    IsoCountry('FJ', 'Fiji'),
    IsoCountry('FK', 'Falkland Islands'),
    IsoCountry('FM', 'Micronesia'),
    IsoCountry('FO', 'Faroe Islands'),
    IsoCountry('FR', 'France'),
    IsoCountry('GA', 'Gabon'),
    IsoCountry('GB', 'United Kingdom'),
    IsoCountry('GD', 'Grenada'),
    IsoCountry('GE', 'Georgia'),
    IsoCountry('GF', 'French Guiana'),
    IsoCountry('GG', 'Guernsey'),
    IsoCountry('GH', 'Ghana'),
    IsoCountry('GI', 'Gibraltar'),
    IsoCountry('GL', 'Greenland'),
    IsoCountry('GM', 'Gambia'),
    IsoCountry('GN', 'Guinea'),
    IsoCountry('GP', 'Guadeloupe'),
    IsoCountry('GQ', 'Equatorial Guinea'),
    IsoCountry('GR', 'Greece'),
    IsoCountry('GS', 'South Georgia and South Sandwich Islands'),
    IsoCountry('GT', 'Guatemala'),
    IsoCountry('GU', 'Guam'),
    IsoCountry('GW', 'Guinea-Bissau'),
    IsoCountry('GY', 'Guyana'),
    IsoCountry('HK', 'Hong Kong'),
    IsoCountry('HM', 'Heard and McDonald Islands'),
    IsoCountry('HN', 'Honduras'),
    IsoCountry('HR', 'Croatia'),
    IsoCountry('HT', 'Haiti'),
    IsoCountry('HU', 'Hungary'),
    IsoCountry('ID', 'Indonesia'),
    IsoCountry('IE', 'Ireland'),
    IsoCountry('IL', 'Israel'),
    IsoCountry('IM', 'Isle of Man'),
    IsoCountry('IN', 'India'),
    IsoCountry('IO', 'British Indian Ocean Territory'),
    IsoCountry('IQ', 'Iraq'),
    IsoCountry('IR', 'Iran'),
    IsoCountry('IS', 'Iceland'),
    IsoCountry('IT', 'Italy'),
    IsoCountry('JE', 'Jersey'),
    IsoCountry('JM', 'Jamaica'),
    IsoCountry('JO', 'Jordan'),
    IsoCountry('JP', 'Japan'),
    IsoCountry('KE', 'Kenya'),
    IsoCountry('KG', 'Kyrgyzstan'),
    IsoCountry('KH', 'Cambodia'),
    IsoCountry('KI', 'Kiribati'),
    IsoCountry('KM', 'Comoros'),
    IsoCountry('KN', 'Saint Kitts and Nevis'),
    IsoCountry('KP', 'North Korea'),
    IsoCountry('KR', 'South Korea'),
    IsoCountry('KW', 'Kuwait'),
    IsoCountry('KY', 'Cayman Islands'),
    IsoCountry('KZ', 'Kazakhstan'),
    IsoCountry('LA', 'Laos'),
    IsoCountry('LB', 'Lebanon'),
    IsoCountry('LC', 'Saint Lucia'),
    IsoCountry('LI', 'Liechtenstein'),
    IsoCountry('LK', 'Sri Lanka'),
    IsoCountry('LR', 'Liberia'),
    IsoCountry('LS', 'Lesotho'),
    IsoCountry('LT', 'Lithuania'),
    IsoCountry('LU', 'Luxembourg'),
    IsoCountry('LV', 'Latvia'),
    IsoCountry('LY', 'Libya'),
    IsoCountry('MA', 'Morocco'),
    IsoCountry('MC', 'Monaco'),
    IsoCountry('MD', 'Moldova'),
    IsoCountry('ME', 'Montenegro'),
    IsoCountry('MF', 'Saint Martin'),
    IsoCountry('MG', 'Madagascar'),
    IsoCountry('MH', 'Marshall Islands'),
    IsoCountry('MK', 'North Macedonia'),
    IsoCountry('ML', 'Mali'),
    IsoCountry('MM', 'Myanmar'),
    IsoCountry('MN', 'Mongolia'),
    IsoCountry('MO', 'Macao'),
    IsoCountry('MP', 'Northern Mariana Islands'),
    IsoCountry('MQ', 'Martinique'),
    IsoCountry('MR', 'Mauritania'),
    IsoCountry('MS', 'Montserrat'),
    IsoCountry('MT', 'Malta'),
    IsoCountry('MU', 'Mauritius'),
    IsoCountry('MV', 'Maldives'),
    IsoCountry('MW', 'Malawi'),
    IsoCountry('MX', 'Mexico'),
    IsoCountry('MY', 'Malaysia'),
    IsoCountry('MZ', 'Mozambique'),
    IsoCountry('NA', 'Namibia'),
    IsoCountry('NC', 'New Caledonia'),
    IsoCountry('NE', 'Niger'),
    IsoCountry('NF', 'Norfolk Island'),
    IsoCountry('NG', 'Nigeria'),
    IsoCountry('NI', 'Nicaragua'),
    IsoCountry('NL', 'Netherlands'),
    IsoCountry('NO', 'Norway'),
    IsoCountry('NP', 'Nepal'),
    IsoCountry('NR', 'Nauru'),
    IsoCountry('NU', 'Niue'),
    IsoCountry('NZ', 'New Zealand'),
    IsoCountry('OM', 'Oman'),
    IsoCountry('PA', 'Panama'),
    IsoCountry('PE', 'Peru'),
    IsoCountry('PF', 'French Polynesia'),
    IsoCountry('PG', 'Papua New Guinea'),
    IsoCountry('PH', 'Philippines'),
    IsoCountry('PK', 'Pakistan'),
    IsoCountry('PL', 'Poland'),
    IsoCountry('PM', 'Saint Pierre and Miquelon'),
    IsoCountry('PN', 'Pitcairn Islands'),
    IsoCountry('PR', 'Puerto Rico'),
    IsoCountry('PS', 'Palestine'),
    IsoCountry('PT', 'Portugal'),
    IsoCountry('PW', 'Palau'),
    IsoCountry('PY', 'Paraguay'),
    IsoCountry('QA', 'Qatar'),
    IsoCountry('RE', 'Réunion'),
    IsoCountry('RO', 'Romania'),
    IsoCountry('RS', 'Serbia'),
    IsoCountry('RU', 'Russia'),
    IsoCountry('RW', 'Rwanda'),
    IsoCountry('SA', 'Saudi Arabia'),
    IsoCountry('SB', 'Solomon Islands'),
    IsoCountry('SC', 'Seychelles'),
    IsoCountry('SD', 'Sudan'),
    IsoCountry('SE', 'Sweden'),
    IsoCountry('SG', 'Singapore'),
    IsoCountry('SH', 'Saint Helena'),
    IsoCountry('SI', 'Slovenia'),
    IsoCountry('SJ', 'Svalbard and Jan Mayen'),
    IsoCountry('SK', 'Slovakia'),
    IsoCountry('SL', 'Sierra Leone'),
    IsoCountry('SM', 'San Marino'),
    IsoCountry('SN', 'Senegal'),
    IsoCountry('SO', 'Somalia'),
    IsoCountry('SR', 'Suriname'),
    IsoCountry('SS', 'South Sudan'),
    IsoCountry('ST', 'São Tomé and Príncipe'),
    IsoCountry('SV', 'El Salvador'),
    IsoCountry('SX', 'Sint Maarten'),
    IsoCountry('SY', 'Syria'),
    IsoCountry('SZ', 'Eswatini'),
    IsoCountry('TC', 'Turks and Caicos Islands'),
    IsoCountry('TD', 'Chad'),
    IsoCountry('TF', 'French Southern Territories'),
    IsoCountry('TG', 'Togo'),
    IsoCountry('TH', 'Thailand'),
    IsoCountry('TJ', 'Tajikistan'),
    IsoCountry('TK', 'Tokelau'),
    IsoCountry('TL', 'Timor-Leste'),
    IsoCountry('TM', 'Turkmenistan'),
    IsoCountry('TN', 'Tunisia'),
    IsoCountry('TO', 'Tonga'),
    IsoCountry('TR', 'Türkiye'),
    IsoCountry('TT', 'Trinidad and Tobago'),
    IsoCountry('TV', 'Tuvalu'),
    IsoCountry('TW', 'Taiwan'),
    IsoCountry('TZ', 'Tanzania'),
    IsoCountry('UA', 'Ukraine'),
    IsoCountry('UG', 'Uganda'),
    IsoCountry('UM', 'U.S. Outlying Islands'),
    IsoCountry('US', 'United States'),
    IsoCountry('UY', 'Uruguay'),
    IsoCountry('UZ', 'Uzbekistan'),
    IsoCountry('VA', 'Vatican City'),
    IsoCountry('VC', 'Saint Vincent and the Grenadines'),
    IsoCountry('VE', 'Venezuela'),
    IsoCountry('VG', 'British Virgin Islands'),
    IsoCountry('VI', 'U.S. Virgin Islands'),
    IsoCountry('VN', 'Vietnam'),
    IsoCountry('VU', 'Vanuatu'),
    IsoCountry('WF', 'Wallis and Futuna'),
    IsoCountry('WS', 'Samoa'),
    IsoCountry('XK', 'Kosovo'),
    IsoCountry('YE', 'Yemen'),
    IsoCountry('YT', 'Mayotte'),
    IsoCountry('ZA', 'South Africa'),
    IsoCountry('ZM', 'Zambia'),
    IsoCountry('ZW', 'Zimbabwe'),
  ];

  /// Extra words the search understands (old or other names).
  static const Map<String, String> _aliases = {
    'AE': 'uae emirates',
    'BN': 'brunei darussalam',
    'BO': 'plurinational',
    'BS': 'the bahamas',
    'BY': 'belorussia',
    'CD': 'congo kinshasa drc',
    'CG': 'congo brazzaville',
    'CI': 'ivory coast',
    'CN': 'prc',
    'CV': 'cabo verde',
    'CZ': 'czech republic',
    'FK': 'malvinas',
    'FM': 'federated states',
    'GB': 'uk great britain britain england scotland wales',
    'GM': 'the gambia',
    'IR': 'persia',
    'KP': 'korea dprk',
    'KR': 'korea republic',
    'LA': 'lao',
    'MK': 'macedonia',
    'MM': 'burma',
    'NL': 'holland',
    'PS': 'palestinian',
    'RU': 'russian federation',
    'SY': 'syrian',
    'SZ': 'swaziland',
    'TL': 'east timor',
    'TR': 'turkey',
    'TW': 'chinese taipei republic of china',
    'US': 'usa america',
    'VA': 'holy see',
    'VE': 'bolivarian',
    'VN': 'viet nam',
  };

  static const Map<String, String> _accents = {
    'å': 'a', 'ä': 'a', 'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ç': 'c',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i', 'î': 'i',
    'ï': 'i', 'ñ': 'n', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', '’': "'",
  };

  static final Map<String, IsoCountry> _byCode = {for (final c in all) c.code: c};

  /// Lower case, no accents: what the search compares.
  static String fold(String s) {
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      b.write(_accents[ch] ?? ch);
    }
    return b.toString();
  }

  static final Map<String, String> _nameKey = {for (final c in all) c.code: fold(c.name)};

  static final Map<String, String> _searchText = {
    for (final c in all) c.code: fold('${c.name} ${_aliases[c.code] ?? ''}'),
  };

  /// All countries, A-Z by name.
  static final List<IsoCountry> byName = [...all]
    ..sort((a, b) => _nameKey[a.code]!.compareTo(_nameKey[b.code]!));

  static bool has(String code) => _byCode.containsKey(code.toUpperCase());

  static String? nameOf(String code) => _byCode[code.toUpperCase()]?.name;

  static String assetPath(String code) => 'assets/flags/${code.toLowerCase()}.png';

  /// Countries whose name (or old name) contains every word of [query], or
  /// whose code is exactly a word of it. Best matches first: the exact code,
  /// then names that start with the text, then the rest A-Z.
  static List<IsoCountry> search(String query) {
    final words = fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return byName;
    final scored = <MapEntry<int, IsoCountry>>[];
    for (final c in all) {
      final text = _searchText[c.code]!;
      final code = c.code.toLowerCase();
      if (!words.every((w) => text.contains(w) || code == w)) continue;
      var score = 3;
      if (words.length == 1) {
        final w = words.first;
        if (code == w) {
          score = 0;
        } else if (text.startsWith(w)) {
          score = 1;
        } else if (text.contains(' $w')) {
          score = 2;
        }
      }
      scored.add(MapEntry(score, c));
    }
    scored.sort((a, b) {
      final d = a.key - b.key;
      return d != 0 ? d : _nameKey[a.value.code]!.compareTo(_nameKey[b.value.code]!);
    });
    return [for (final e in scored) e.value];
  }
}
