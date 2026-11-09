import 'dart:async';
import 'dart:io';

import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';
import 'package:dakhl_restaurant/catalog/product_photo_draft_controller.dart';
import 'package:dakhl_restaurant/inventory/inventory_commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../parties/parties_view_model_test.dart' show setup;

void main() {
  test('eight reference choices retain frozen image bytes and labels', () {
    const labels = [
      'كباب لحم',
      'كباب دجاج',
      'دجاج مشوي',
      'دليمية',
      'تمن أحمر',
      'مقبلات',
      'ماء',
      'مشروب غازي',
    ];
    expect(ProductPhotoReference.canonicalKeys.length, 8);
    for (var i = 0; i < 8; i++) {
      final key = ProductPhotoReference.canonicalKeys[i];
      expect(ProductPhotoReference.labelFor(key), labels[i]);
      final asset = File(ProductPhotoReference.assetPathFor(key)!);
      final original = File(
        'electron-reference/app/ui/photos/thumbs/$key-480.webp',
      );
      expect(asset.readAsBytesSync(), original.readAsBytesSync());
    }
    expect(ProductPhotoReference.labelFor(null), 'بدون صورة');
    expect(ProductPhotoReference.isValidKey('../../other'), isFalse);
  });

  test(
    'new product photo survives portable codec and repository reopen',
    () async {
      final (store, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final controller = ProductPhotoDraftController.forNew(
        viewModel: model,
        id: 'photo-product',
        name: 'كباب',
        price: 12000,
        initialPhoto: 'beef-kebab',
      );
      addTearDown(() {
        controller.dispose();
        model.dispose();
        parties.dispose();
      });
      expect(controller.previousPhoto.hasPhoto, isFalse);
      expect(
        await controller.saveProduct(session: model.beginEdit()),
        isA<CapabilitySuccess>(),
      );
      expect(controller.previousPhoto.key, 'beef-kebab');
      expect(controller.isNewProduct, isFalse);
      final portable = repository.codec.decodeBytes(
        repository.codec.encode(repository.document!),
      );
      expect(
        (portable.toJson()['products'] as List).single['photo'],
        'beef-kebab',
      );
      final reopened = AccountsRepository(store: store);
      expect(await reopened.open(), isA<CapabilitySuccess>());
      final reloaded = ProductPhotoDraftController.forExisting(
        viewModel: CatalogViewModel(reopened),
        productId: 'photo-product',
      );
      expect(reloaded.preview.assetPath, 'assets/ui/beef-kebab-480.webp');
      reloaded.dispose();
      reloaded.viewModel.dispose();
    },
  );

  test(
    'replacement and removal each need their own acknowledged save',
    () async {
      final (_, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final controller = ProductPhotoDraftController.forNew(
        viewModel: model,
        id: 'p',
        name: 'مشروب',
        price: 1000,
        initialPhoto: 'cola',
      );
      addTearDown(() {
        controller.dispose();
        model.dispose();
        parties.dispose();
      });
      await controller.saveProduct(session: model.beginEdit());
      expect(controller.selectReferencePhoto('water'), isTrue);
      expect(controller.previousPhoto.key, 'cola');
      expect(
        await controller.saveProduct(session: model.beginEdit()),
        isA<CapabilitySuccess>(),
      );
      expect(controller.previousPhoto.key, 'water');
      controller.removePhoto();
      expect(controller.previousPhoto.key, 'water');
      expect(
        await controller.saveProduct(session: model.beginEdit()),
        isA<CapabilitySuccess>(),
      );
      expect(controller.previousPhoto.hasPhoto, isFalse);
      expect(
        (repository.document!.toJson()['products'] as List).single.containsKey(
          'photo',
        ),
        isFalse,
      );
    },
  );

  for (final failure in ['unavailable', 'commit_unknown']) {
    test(
      '$failure retains photo input without claiming saved success',
      () async {
        final (store, repository, parties) = await setup();
        final model = CatalogViewModel(repository);
        final controller = ProductPhotoDraftController.forNew(
          viewModel: model,
          id: 'p',
          name: 'ماء',
          price: 500,
          initialPhoto: 'water',
        );
        addTearDown(() {
          controller.dispose();
          model.dispose();
          parties.dispose();
        });
        store.failure = failure;
        final result = await controller.saveProduct(session: model.beginEdit());
        expect(result, isA<CapabilityFailure>());
        expect(controller.errorCode, failure);
        expect(controller.preview.key, 'water');
        expect(controller.previousPhoto.hasPhoto, isFalse);
        expect((repository.document!.toJson()['products'] as List), isEmpty);
      },
    );
  }

  test(
    'caller owns exact opening movement identity, date, quantity and note',
    () async {
      final (_, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final controller = ProductPhotoDraftController.forNew(
        viewModel: model,
        id: 'p',
        name: 'Stocked product',
        price: 100,
        initialPhoto: 'water',
      );
      addTearDown(() {
        controller.dispose();
        model.dispose();
        parties.dispose();
      });
      final movement = InventoryMovement(
        id: 'opening-from-caller',
        productId: 'p',
        quantityUnits: BigInt.from(1001),
        effectiveDate: DateOnly.parse(
          '2026-01-01',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        kind: StockEntryKind.opening,
        createdAt: '2026-01-02T00:00:00.000Z',
        note: 'Caller provenance',
      );
      expect(
        await controller.saveProduct(
          session: model.beginEdit(),
          opening: movement,
        ),
        isA<CapabilitySuccess>(),
      );
      final entry =
          (repository.document!.toJson()['stockEntries'] as List).single;
      expect(entry['id'], movement.id);
      expect(entry['date'], '2026-01-01');
      expect(entry['quantity'], 1.001);
      expect(entry['createdAt'], movement.createdAt);
      expect(entry['note'], movement.note);
    },
  );

  test(
    'invalid reference selection keeps draft and acknowledged state intact',
    () async {
      final (_, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final controller = ProductPhotoDraftController.forNew(
        viewModel: model,
        id: 'p',
        name: 'صنف',
        price: 100,
        initialPhoto: 'cola',
      );
      addTearDown(() {
        controller.dispose();
        model.dispose();
        parties.dispose();
      });
      expect(controller.selectReferencePhoto('local-file.webp'), isFalse);
      expect(controller.errorCode, 'invalid_photo');
      expect(controller.draft.photo, 'cola');
      expect(controller.preview.key, 'cola');
      expect(controller.previousPhoto.hasPhoto, isFalse);
    },
  );

  test('disposal after dispatch suppresses late notification, not the commit receipt', () async {
    final (store, repository, parties) = await setup();
    final model = CatalogViewModel(repository);
    final controller = ProductPhotoDraftController.forNew(
      viewModel: model,
      id: 'p',
      name: 'صنف',
      price: 100,
      initialPhoto: 'water',
    );
    addTearDown(() {
      controller.dispose();
      model.dispose();
      parties.dispose();
    });
    store.delay = Completer<void>();
    var notifications = 0;
    controller.addListener(() => notifications++);
    final saving = controller.saveProduct(session: model.beginEdit());
    addTearDown(() async {
      if (!store.delay!.isCompleted) store.delay!.complete();
      await saving;
    });
    controller.dispose();
    final before = notifications;
    store.delay!.complete();
    expect(await saving, isA<CapabilitySuccess>());
    expect(notifications, before);
  });
}
