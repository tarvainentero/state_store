class Complex {
  final String id;
  final String name;
  final String? description;
  final List<int> numbers = [3, 4, 7, 11, 15];

  Complex({required this.id, required this.name, this.description});

  Complex.demo() : this(id: 'trip', name: 'trap', description: 'trop');

  Complex.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        description = json['description'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'numbers': numbers,
      };
}
