import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh defaults receive stable system keys on category rows', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalFinanceRepository(database);
    await repository.initialize();

    final fee = database.db.select(
      "SELECT name,system_key FROM categories WHERE system_key='expense.transfer_fee'",
    ).single;
    final salary = database.db.select(
      "SELECT name,system_key FROM categories WHERE system_key='income.salary'",
    ).single;

    expect(fee['name'], 'Biaya Transfer');
    expect(fee['system_key'], 'expense.transfer_fee');
    expect(salary['name'], 'Gaji');
    expect(salary['system_key'], 'income.salary');
  });

  test('renamed transfer-fee category keeps identity and automatic fee posting', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalFinanceRepository(
      database,
      clock: () => DateTime(2026, 9, 15, 12),
    );
    await repository.initialize();

    final source = (await repository.listAccounts()).single;
    final destinationId = await repository.createAccount(
      name: 'Bank tujuan',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );
    final feeRow = database.db.select(
      "SELECT id FROM categories WHERE system_key='expense.transfer_fee'",
    ).single;
    final feeCategoryId = feeRow['id'] as String;

    database.db.execute(
      'UPDATE categories SET name=?,updated_at=?,version=version+1 WHERE id=?',
      ['Admin Transfer', '2026-09-15T04:00:00Z', feeCategoryId],
    );

    await repository.createTransfer(
      amountMinor: 100000,
      sourceAccountId: source.id,
      destinationAccountId: destinationId,
      feeMinor: 2500,
      occurredAt: DateTime(2026, 9, 15, 10),
    );

    final identity = database.db.select(
      'SELECT name,system_key FROM categories WHERE id=?',
      [feeCategoryId],
    ).single;
    final feeSplit = database.db.select(
      '''SELECT s.category_id,c.name,t.primary_amount_minor
         FROM transactions t
         JOIN transaction_splits s ON s.transaction_id=t.id
         JOIN categories c ON c.id=s.category_id
         WHERE t.type='EXPENSE' AND t.primary_amount_minor=2500''',
    ).single;

    expect(identity['name'], 'Admin Transfer');
    expect(identity['system_key'], 'expense.transfer_fee');
    expect(feeSplit['category_id'], feeCategoryId);
    expect(feeSplit['name'], 'Admin Transfer');
  });

  test('archiving system category does not break engine-owned transfer fee', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalFinanceRepository(
      database,
      clock: () => DateTime(2026, 9, 15, 12),
    );
    await repository.initialize();

    final source = (await repository.listAccounts()).single;
    final destinationId = await repository.createAccount(
      name: 'Bank tujuan',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );
    final feeCategoryId = database.db.select(
      "SELECT id FROM categories WHERE system_key='expense.transfer_fee'",
    ).single['id'] as String;

    await repository.archiveCategory(feeCategoryId);
    expect(
      (await repository.listCategories(type: CategoryType.expense))
          .any((category) => category.id == feeCategoryId),
      isFalse,
    );

    await repository.createTransfer(
      amountMinor: 50000,
      sourceAccountId: source.id,
      destinationAccountId: destinationId,
      feeMinor: 1000,
      occurredAt: DateTime(2026, 9, 15, 11),
    );

    final feeSplit = database.db.select(
      '''SELECT s.category_id FROM transactions t
         JOIN transaction_splits s ON s.transaction_id=t.id
         WHERE t.type='EXPENSE' AND t.primary_amount_minor=1000''',
    ).single;
    expect(feeSplit['category_id'], feeCategoryId);
  });

  test('replacement category with same display name cannot steal a stable key', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalFinanceRepository(database);
    await repository.initialize();

    final originalId = database.db.select(
      "SELECT id FROM categories WHERE system_key='expense.transfer_fee'",
    ).single['id'] as String;
    await repository.archiveCategory(originalId);
    final replacementId = await repository.createCategory(
      name: 'Biaya Transfer',
      type: CategoryType.expense,
    );

    final original = database.db.select(
      'SELECT system_key FROM categories WHERE id=?',
      [originalId],
    ).single;
    final replacement = database.db.select(
      'SELECT system_key FROM categories WHERE id=?',
      [replacementId],
    ).single;

    expect(original['system_key'], 'expense.transfer_fee');
    expect(replacement['system_key'], isNull);
  });

  test('system keys are unique when explicitly restored with category rows', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await database.open();

    final now = DateTime.utc(2026, 9, 15).toIso8601String();
    database.db.execute(
      '''INSERT INTO categories(id,type,name,system_key,created_at,updated_at,version)
         VALUES (?,?,?,?,?,?,1)''',
      ['manual-1', 'EXPENSE', 'A', 'custom.system', now, now],
    );

    expect(
      () => database.db.execute(
        '''INSERT INTO categories(id,type,name,system_key,created_at,updated_at,version)
           VALUES (?,?,?,?,?,?,1)''',
        ['manual-2', 'EXPENSE', 'B', 'custom.system', now, now],
      ),
      throwsA(anything),
    );
  });
}
