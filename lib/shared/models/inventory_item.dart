
class InventoryItem {
  final String id;
  final String name;
  final String type; // "Material", "Weapon", "Armor", "Accessory", "Consumable", "Quest", "Rune"
  final String rarity; // "Common", "Uncommon", "Rare", "Epic", "Legendary"
  final String description;
  final int quantity;
  final ItemStats? stats;
  final int? value;
  final String? imageUrl;

  InventoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.rarity,
    required this.description,
    this.quantity = 1,
    this.stats,
    this.value,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'rarity': rarity,
      'description': description,
      'quantity': quantity,
      'stats': stats?.toJson(),
      'value': value,
      'imageUrl': imageUrl,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      rarity: json['rarity'],
      description: json['description'],
      quantity: json['quantity'] ?? 1,
      stats: json['stats'] != null ? ItemStats.fromJson(json['stats']) : null,
      value: json['value'],
      imageUrl: json['imageUrl'],
    );
  }
}

class ItemStats {
  final int? str;
  final int? vit;
  final int? agi;
  final int? intStat; // 'int' is a reserved keyword
  final int? per;
  final int? hp; // For consumables
  final int? mp; // For consumables
  final Resistance? resistance;

  ItemStats({
    this.str,
    this.vit,
    this.agi,
    this.intStat,
    this.per,
    this.hp,
    this.mp,
    this.resistance,
  });

  Map<String, dynamic> toJson() {
    return {
      'str': str,
      'vit': vit,
      'agi': agi,
      'int': intStat,
      'per': per,
      'hp': hp,
      'mp': mp,
      'resistance': resistance?.toJson(),
    };
  }

  factory ItemStats.fromJson(Map<String, dynamic> json) {
    return ItemStats(
      str: json['str'],
      vit: json['vit'],
      agi: json['agi'],
      intStat: json['int'],
      per: json['per'],
      hp: json['hp'],
      mp: json['mp'],
      resistance: json['resistance'] != null ? Resistance.fromJson(json['resistance']) : null,
    );
  }
}

class Resistance {
  final int? fire;
  final int? ice;
  final int? lightning;
  final int? poison;
  final int? dark;

  Resistance({this.fire, this.ice, this.lightning, this.poison, this.dark});

  Map<String, dynamic> toJson() {
    return {
      'fire': fire,
      'ice': ice,
      'lightning': lightning,
      'poison': poison,
      'dark': dark,
    };
  }

  factory Resistance.fromJson(Map<String, dynamic> json) {
    return Resistance(
      fire: json['fire'],
      ice: json['ice'],
      lightning: json['lightning'],
      poison: json['poison'],
      dark: json['dark'],
    );
  }
}
