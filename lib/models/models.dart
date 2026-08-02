// Modelos de dados, equivalentes às interfaces TypeScript em src/app/types.

class Creator {
  final String id;
  final String name;
  final String email;

  const Creator({required this.id, required this.name, required this.email});

  factory Creator.fromJson(Map<String, dynamic> j) => Creator(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

class User {
  final String id;
  final String email;
  final String name;
  final String? avatar;
  final String provider; // 'email' | 'google'
  final bool emailVerified;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
    required this.provider,
    this.emailVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        email: j['email'] as String,
        name: j['name'] as String,
        avatar: j['avatar'] as String?,
        provider: j['provider'] as String? ?? 'email',
        emailVerified: j['emailVerified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatar': avatar,
        'provider': provider,
        'emailVerified': emailVerified,
      };
}

class MotorcyclePart {
  final String id;
  final String code;
  final String name;
  final String category;
  final String brand;
  final double price;
  final int stock;
  final String? description;
  final String? barcode;
  final Creator createdBy;
  final String createdAt;

  const MotorcyclePart({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.brand,
    required this.price,
    required this.stock,
    this.description,
    this.barcode,
    required this.createdBy,
    required this.createdAt,
  });

  factory MotorcyclePart.fromJson(Map<String, dynamic> j) => MotorcyclePart(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        brand: j['brand'] as String,
        price: (j['price'] as num).toDouble(),
        stock: (j['stock'] as num).toInt(),
        description: j['description'] as String?,
        barcode: j['barcode'] as String?,
        createdBy: Creator.fromJson(j['createdBy'] as Map<String, dynamic>),
        createdAt: j['createdAt'] as String,
      );

  MotorcyclePart copyWith({int? stock}) => MotorcyclePart(
        id: id,
        code: code,
        name: name,
        category: category,
        brand: brand,
        price: price,
        stock: stock ?? this.stock,
        description: description,
        barcode: barcode,
        createdBy: createdBy,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'category': category,
        'brand': brand,
        'price': price,
        'stock': stock,
        'description': description,
        'barcode': barcode,
        'createdBy': createdBy.toJson(),
        'createdAt': createdAt,
      };
}

class PartUsed {
  final String partId;
  final String partName;
  final int quantity;
  final double price;

  const PartUsed({
    required this.partId,
    required this.partName,
    required this.quantity,
    required this.price,
  });

  factory PartUsed.fromJson(Map<String, dynamic> j) => PartUsed(
        partId: j['partId'] as String,
        partName: j['partName'] as String,
        quantity: (j['quantity'] as num).toInt(),
        price: (j['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'partId': partId,
        'partName': partName,
        'quantity': quantity,
        'price': price,
      };
}

class ServiceOrder {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String motorcycleBrand;
  final String motorcycleModel;
  final String motorcyclePlate;
  final String problem;
  final String status; // pending | in-progress | completed | cancelled
  final String mechanicId;
  final String mechanicName;
  final List<String> photos; // base64 data URLs ou caminhos
  final List<PartUsed> partsUsed;
  final double laborCost;
  final double totalCost;
  final Creator createdBy;
  final String createdAt;
  final String? completedAt;

  const ServiceOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.motorcycleBrand,
    required this.motorcycleModel,
    required this.motorcyclePlate,
    required this.problem,
    required this.status,
    required this.mechanicId,
    required this.mechanicName,
    required this.photos,
    required this.partsUsed,
    required this.laborCost,
    required this.totalCost,
    required this.createdBy,
    required this.createdAt,
    this.completedAt,
  });

  factory ServiceOrder.fromJson(Map<String, dynamic> j) => ServiceOrder(
        id: j['id'] as String,
        orderNumber: j['orderNumber'] as String,
        customerName: j['customerName'] as String,
        customerPhone: j['customerPhone'] as String,
        motorcycleBrand: j['motorcycleBrand'] as String,
        motorcycleModel: j['motorcycleModel'] as String,
        motorcyclePlate: j['motorcyclePlate'] as String,
        problem: j['problem'] as String,
        status: j['status'] as String,
        mechanicId: j['mechanicId'] as String,
        mechanicName: j['mechanicName'] as String,
        photos: (j['photos'] as List<dynamic>? ?? []).cast<String>(),
        partsUsed: (j['partsUsed'] as List<dynamic>? ?? [])
            .map((e) => PartUsed.fromJson(e as Map<String, dynamic>))
            .toList(),
        laborCost: (j['laborCost'] as num).toDouble(),
        totalCost: (j['totalCost'] as num).toDouble(),
        createdBy: Creator.fromJson(j['createdBy'] as Map<String, dynamic>),
        createdAt: j['createdAt'] as String,
        completedAt: j['completedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'motorcycleBrand': motorcycleBrand,
        'motorcycleModel': motorcycleModel,
        'motorcyclePlate': motorcyclePlate,
        'problem': problem,
        'status': status,
        'mechanicId': mechanicId,
        'mechanicName': mechanicName,
        'photos': photos,
        'partsUsed': partsUsed.map((e) => e.toJson()).toList(),
        'laborCost': laborCost,
        'totalCost': totalCost,
        'createdBy': createdBy.toJson(),
        'createdAt': createdAt,
        'completedAt': completedAt,
      };
}

class Employee {
  final String id;
  final String name;
  final String cpf;
  final String role; // mechanic | attendant | manager | cashier
  final String phone;
  final String email;
  final String hireDate;
  final double salary;
  final String status; // active | inactive
  final Creator createdBy;
  final String createdAt;

  const Employee({
    required this.id,
    required this.name,
    required this.cpf,
    required this.role,
    required this.phone,
    required this.email,
    required this.hireDate,
    required this.salary,
    required this.status,
    required this.createdBy,
    required this.createdAt,
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        name: j['name'] as String,
        cpf: j['cpf'] as String,
        role: j['role'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String,
        hireDate: j['hireDate'] as String,
        salary: (j['salary'] as num).toDouble(),
        status: j['status'] as String,
        createdBy: Creator.fromJson(j['createdBy'] as Map<String, dynamic>),
        createdAt: j['createdAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cpf': cpf,
        'role': role,
        'phone': phone,
        'email': email,
        'hireDate': hireDate,
        'salary': salary,
        'status': status,
        'createdBy': createdBy.toJson(),
        'createdAt': createdAt,
      };
}

class Transaction {
  final String id;
  final String type; // entrada | saida
  final String category;
  final String description;
  final double amount;
  final String date; // yyyy-MM-dd
  final String month; // yyyy-MM

  const Transaction({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.month,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        type: j['type'] as String,
        category: j['category'] as String,
        description: j['description'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: j['date'] as String,
        month: j['month'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'category': category,
        'description': description,
        'amount': amount,
        'date': date,
        'month': month,
      };
}

/// Categoria personalizada de transação, por loja e tipo (entrada/saída).
class FinanceCategory {
  final String id;
  final String storeId;
  final String type; // entrada | saida
  final String name;

  const FinanceCategory({
    required this.id,
    required this.storeId,
    required this.type,
    required this.name,
  });

  factory FinanceCategory.fromJson(Map<String, dynamic> j) => FinanceCategory(
        id: j['id'] as String,
        storeId: j['storeId'] as String,
        type: j['type'] as String,
        name: j['name'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeId': storeId,
        'type': type,
        'name': name,
      };
}

class BusinessStore {
  final String id;
  final String name;
  final String type;
  final String icon;
  final int color; // valor ARGB

  const BusinessStore({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  factory BusinessStore.fromJson(Map<String, dynamic> j) => BusinessStore(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        icon: j['icon'] as String,
        color: (j['color'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
      };
}
