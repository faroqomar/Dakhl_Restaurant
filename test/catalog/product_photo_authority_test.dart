import 'dart:async';

import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';
import 'package:dakhl_restaurant/catalog/product_photo_draft_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

import '../parties/parties_view_model_test.dart' show setup;

Future<ProductPhotoDraftController> existing(CatalogViewModel model) async {
  final created = await model.createProduct({
    'id': 'p',
    'name': 'Original',
    'code': '',
    'group': '',
    'unit': 'piece',
    'price': 100,
    'photo': 'cola',
    'trackStock': false,
    'minStock': 0,
    'archived': false,
  }, session: model.beginEdit());
  expect(created, isA<CapabilitySuccess>());
  return ProductPhotoDraftController.forExisting(
    viewModel: model,
    productId: 'p',
  );
}

void main() {
  test(
    'unsaved selections and removal preserve acknowledged photo baseline',
    () async {
      final (_, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final controller = await existing(model);
      addTearDown(() {
        controller.dispose();
        model.dispose();
        parties.dispose();
      });
      controller.selectReferencePhoto('water');
      controller.selectReferencePhoto('beef-kebab');
      controller.removePhoto();
      expect(controller.previousPhoto.key, 'cola');
      expect(
        (repository.document!.toJson()['products'] as List).single['photo'],
        'cola',
      );
      expect(controller.preview.hasPhoto, isFalse);
    },
  );

  test('busy photo actions reject without replacing submitted or acknowledged input', () async {
    final (store, repository, parties) = await setup();
    final model = CatalogViewModel(repository);
    final controller = await existing(model);
    addTearDown(() {
      controller.dispose();
      model.dispose();
      parties.dispose();
    });
    controller.selectReferencePhoto('beef-kebab');
    store.delay = Completer<void>();
    final saving = controller.saveProduct(session: model.beginEdit());
    addTearDown(() async {
      if (!store.delay!.isCompleted) store.delay!.complete();
      await saving;
    });
    expect(controller.selectReferencePhoto('water'), isFalse);
    controller.removePhoto();
    expect(controller.preview.key, 'beef-kebab');
    expect(controller.previousPhoto.key, 'cola');
    store.delay!.complete();
    expect(await saving, isA<CapabilitySuccess>());
    expect(controller.previousPhoto.key, 'beef-kebab');
    expect(controller.selectReferencePhoto('water'), isTrue);
    expect(controller.previousPhoto.key, 'beef-kebab');
  });

  test(
    'fresh caller session cannot retarget an older form after account change',
    () async {
      final (store, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final controller = await existing(model);
      addTearDown(() {
        controller.dispose();
        model.dispose();
        parties.dispose();
      });
      final raw = Map<String, Object?>.from(repository.document!.toJson());
      raw['products'] = [
        {
          ...(raw['products'] as List).single as Map<String, Object?>,
          'name': 'Replacement account product',
          'photo': 'water',
        },
      ];
      await repository.save(repository.codec.decodeJson(raw), replace: true);
      final writes = store.writes;
      final result = await controller.saveProduct(session: model.beginEdit());
      expect(result, isA<CapabilityFailure>());
      expect((result as CapabilityFailure).code, 'stale_revision');
      expect(store.writes, writes);
      expect(
        (repository.document!.toJson()['products'] as List).single['name'],
        'Replacement account product',
      );
    },
  );

  test(
    'listener disposal before dispatch prevents the product write',
    () async {
      final (store, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final controller = await existing(model);
      addTearDown(() {
        controller.dispose();
        model.dispose();
        parties.dispose();
      });
      final writes = store.writes;
      controller.addListener(() {
        if (controller.isBusy) controller.dispose();
      });
      final result = await controller.saveProduct(session: model.beginEdit());
      expect(result, isA<CapabilityFailure>());
      expect((result as CapabilityFailure).code, 'disposed');
      expect(store.writes, writes);
    },
  );
}
