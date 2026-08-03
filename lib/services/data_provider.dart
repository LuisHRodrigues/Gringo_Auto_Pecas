import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/models.dart';

/// Centraliza o estado dos dados do sistema (peças, ordens, funcionários,
/// transações e lojas) com persistência em tempo real no Cloud Firestore.
///
/// Mantém a mesma API pública usada pelas páginas (getters síncronos +
/// add/update/delete). Os métodos de escrita disparam writes no Firestore;
/// a UI é atualizada pelos listeners de snapshot, que mantêm os caches locais
/// e chamam [notifyListeners].
class DataProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<StreamSubscription> _subs = [];
  String? _currentUid;

  List<MotorcyclePart> _parts = [];
  List<ServiceOrder> _orders = [];
  List<Employee> _employees = [];
  List<BusinessStore> _stores = [];
  List<FinanceCategory> _categories = [];
  // Transações reais persistidas, agrupadas por loja (não inclui as
  // sintéticas derivadas de OS concluídas, que são calculadas em leitura).
  final Map<String, List<Transaction>> _transactionsByStore = {};

  List<MotorcyclePart> get parts => List.unmodifiable(_parts);
  List<ServiceOrder> get orders => List.unmodifiable(_orders);
  List<Employee> get employees => List.unmodifiable(_employees);
  List<BusinessStore> get stores => List.unmodifiable(_stores);

  CollectionReference<Map<String, dynamic>> get _partsRef =>
      _db.collection('parts');
  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _db.collection('serviceOrders');
  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _db.collection('employees');
  CollectionReference<Map<String, dynamic>> get _storesRef =>
      _db.collection('stores');
  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _db.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _db.collection('categories');

  /// Deve ser chamado sempre que o usuário autenticado mudar (login, logout
  /// ou troca de conta). Um listener de `snapshots()` que recebe
  /// permission-denied (ex.: os listeners chegam a ser criados antes do
  /// login terminar, ou o usuário deslogou) não se recupera sozinho quando a
  /// permissão volta a ficar válida — por isso os listeners precisam ser
  /// cancelados e recriados do zero a cada troca de usuário, em vez de serem
  /// criados uma única vez no construtor.
  void syncWithAuth(String? uid) {
    if (uid == _currentUid) return;
    _currentUid = uid;
    _stopListening();
    _clearLocalState();
    if (uid != null) {
      _ensureDefaultStore();
      _startListening();
    }
    notifyListeners();
  }

  void _startListening() {
    _listenParts();
    _listenOrders();
    _listenEmployees();
    _listenStores();
    _listenTransactions();
    _listenCategories();
  }

  void _stopListening() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void _clearLocalState() {
    _parts = [];
    _orders = [];
    _employees = [];
    _stores = [];
    _categories = [];
    _transactionsByStore.clear();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  // ---------------- Peças ----------------
  void _listenParts() {
    _subs.add(_partsRef.snapshots().listen((snap) {
      _parts = snap.docs.map((d) => MotorcyclePart.fromJson(d.data())).toList();
      notifyListeners();
    }));
  }

  Future<void> addPart(MotorcyclePart part) =>
      _partsRef.doc(part.id).set(part.toJson());

  Future<void> updatePart(MotorcyclePart part) =>
      _partsRef.doc(part.id).set(part.toJson());

  Future<void> deletePart(String id) => _partsRef.doc(id).delete();

  // ---------------- Ordens de serviço ----------------
  void _listenOrders() {
    _subs.add(_ordersRef.snapshots().listen((snap) {
      _orders = snap.docs.map((d) => ServiceOrder.fromJson(d.data())).toList();
      notifyListeners();
    }));
  }

  Future<void> addOrder(ServiceOrder order) =>
      _ordersRef.doc(order.id).set(order.toJson());

  Future<void> updateOrder(ServiceOrder order) =>
      _ordersRef.doc(order.id).set(order.toJson());

  Future<void> deleteOrder(String id) => _ordersRef.doc(id).delete();

  // ---------------- Funcionários ----------------
  void _listenEmployees() {
    _subs.add(_employeesRef.snapshots().listen((snap) {
      _employees = snap.docs.map((d) => Employee.fromJson(d.data())).toList();
      notifyListeners();
    }));
  }

  Future<void> addEmployee(Employee e) =>
      _employeesRef.doc(e.id).set(e.toJson());

  Future<void> updateEmployee(Employee e) =>
      _employeesRef.doc(e.id).set(e.toJson());

  Future<void> deleteEmployee(String id) => _employeesRef.doc(id).delete();

  // ---------------- Lojas ----------------
  static const _defaultStore = BusinessStore(
    // Mantém o id histórico 'motogest' — é a chave usada em storeId nos
    // documentos do Firestore já existentes; mudar quebraria os dados atuais.
    id: 'motogest',
    name: 'GMP Gestor Oficina',
    type: 'Oficina de Motos',
    icon: 'wrench',
    color: 0xFF3B82F6,
  );

  Future<void> _ensureDefaultStore() async {
    try {
      final doc = await _storesRef.doc(_defaultStore.id).get();
      if (!doc.exists) {
        await _storesRef.doc(_defaultStore.id).set(_defaultStore.toJson());
      }
    } catch (_) {
      // Offline na primeira execução: o store padrão aparece quando online.
    }
  }

  void _listenStores() {
    _subs.add(_storesRef.snapshots().listen((snap) {
      _stores = snap.docs.map((d) => BusinessStore.fromJson(d.data())).toList();
      notifyListeners();
    }));
  }

  Future<void> addStore(BusinessStore s) =>
      _storesRef.doc(s.id).set(s.toJson());

  Future<void> deleteStore(String id) async {
    await _storesRef.doc(id).delete();
    // Remove as transações e categorias personalizadas da loja em lote.
    final batch = _db.batch();
    final txs = await _transactionsRef.where('storeId', isEqualTo: id).get();
    for (final d in txs.docs) {
      batch.delete(d.reference);
    }
    final cats = await _categoriesRef.where('storeId', isEqualTo: id).get();
    for (final d in cats.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  // ---------------- Transações ----------------
  void _listenTransactions() {
    _subs.add(_transactionsRef.snapshots().listen((snap) {
      final byStore = <String, List<Transaction>>{};
      for (final d in snap.docs) {
        final data = d.data();
        final storeId = data['storeId'] as String? ?? 'motogest';
        final t = Transaction.fromJson(data);
        // Ignora eventuais transações sintéticas antigas persistidas.
        if (t.id.startsWith('os-')) continue;
        byStore.putIfAbsent(storeId, () => []).add(t);
      }
      _transactionsByStore
        ..clear()
        ..addAll(byStore);
      notifyListeners();
    }));
  }

  /// Transações de uma loja: as reais persistidas + (na loja principal) as
  /// sintéticas derivadas das OS concluídas, calculadas em tempo real.
  List<Transaction> transactionsOf(String storeId) {
    final real = _transactionsByStore[storeId] ?? const <Transaction>[];
    if (storeId != 'motogest') return List.unmodifiable(real);
    return List.unmodifiable([...real, ..._ordersAsTransactions()]);
  }

  /// Compatibilidade com a API anterior; a sincronização agora é reativa.
  List<Transaction> loadTransactions(String storeId) => transactionsOf(storeId);

  List<Transaction> _ordersAsTransactions() {
    final completed = _orders.where((o) => o.status == 'completed');
    return [
      for (final order in completed)
        () {
          final completedDate = order.completedAt ?? order.createdAt;
          final dt = DateTime.parse(completedDate);
          final month = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
          return Transaction(
            id: 'os-${order.id}',
            type: 'entrada',
            category: 'Serviços',
            description:
                'OS #${order.orderNumber} - ${order.customerName} - ${order.motorcycleBrand} ${order.motorcycleModel}',
            amount: order.totalCost,
            date: completedDate.split('T').first,
            month: month,
          );
        }(),
    ];
  }

  Future<void> addTransaction(String storeId, Transaction t) =>
      _transactionsRef.doc(t.id).set({
        ...t.toJson(),
        'storeId': storeId,
      });

  Future<void> updateTransaction(String storeId, Transaction t) =>
      _transactionsRef.doc(t.id).set({
        ...t.toJson(),
        'storeId': storeId,
      });

  Future<void> deleteTransaction(String id) =>
      _transactionsRef.doc(id).delete();

  // ---------------- Categorias personalizadas ----------------
  void _listenCategories() {
    _subs.add(_categoriesRef.snapshots().listen((snap) {
      _categories =
          snap.docs.map((d) => FinanceCategory.fromJson(d.data())).toList();
      notifyListeners();
    }));
  }

  /// Categorias personalizadas de uma loja para um tipo (entrada/saida),
  /// ordenadas por nome.
  List<FinanceCategory> customCategoriesFor(String storeId, String type) {
    final list = _categories
        .where((c) => c.storeId == storeId && c.type == type)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(list);
  }

  Future<void> addCategory(String storeId, String type, String name) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return _categoriesRef.doc(id).set(
          FinanceCategory(id: id, storeId: storeId, type: type, name: name)
              .toJson(),
        );
  }

  Future<void> deleteCategory(String id) => _categoriesRef.doc(id).delete();

  /// Renomeia uma categoria personalizada e migra as transações da mesma loja
  /// que usavam o nome antigo, para manter os gráficos/agrupamentos coerentes.
  Future<void> renameCategory(FinanceCategory category, String newName) async {
    final batch = _db.batch();
    batch.update(_categoriesRef.doc(category.id), {'name': newName});
    final txs = await _transactionsRef
        .where('storeId', isEqualTo: category.storeId)
        .get();
    for (final d in txs.docs) {
      if (d.data()['category'] == category.name) {
        batch.update(d.reference, {'category': newName});
      }
    }
    await batch.commit();
  }
}
