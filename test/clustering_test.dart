/// Tests for clustering parameter models and adaptive selection.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('DBSCANParams', () {
    test('has correct defaults', () {
      const params = DBSCANParams();

      expect(params.eps, equals(0.5));
      expect(params.minPoints, equals(5));
      expect(params.metric, equals('cosine'));
      expect(params.useSpatialIndex, isFalse);
    });

    test('toMap() includes all fields', () {
      const params = DBSCANParams(
        eps: 0.3,
        minPoints: 10,
        metric: 'euclidean',
        useSpatialIndex: true,
      );

      final map = params.toMap();
      expect(map['eps'], equals(0.3));
      expect(map['minPoints'], equals(10));
      expect(map['metric'], equals('euclidean'));
      expect(map['useSpatialIndex'], isTrue);
    });
  });

  group('HDBSCANParams', () {
    test('has correct defaults', () {
      const params = HDBSCANParams();

      expect(params.minClusterSize, equals(5));
      expect(params.minSamples, equals(3));
      expect(params.metric, equals('cosine'));
      expect(params.clusterSelectionMethod, equals('eom'));
      expect(params.clusterSelectionEpsilon, equals(0.0));
      expect(params.allowSingleCluster, isFalse);
    });

    test('toMap() includes all fields', () {
      const params = HDBSCANParams();
      final map = params.toMap();

      expect(map, containsPair('minClusterSize', 5));
      expect(map, containsPair('minSamples', 3));
      expect(map, containsPair('metric', 'cosine'));
      expect(map, containsPair('clusterSelectionMethod', 'eom'));
    });
  });

  group('KMeansParams', () {
    test('requires k parameter', () {
      const params = KMeansParams(k: 5);

      expect(params.k, equals(5));
      expect(params.maxIterations, equals(100));
      expect(params.initMethod, equals('k-means++'));
      expect(params.nInit, equals(10));
      expect(params.tolerance, equals(1e-4));
    });

    test('toMap() includes k and all fields', () {
      const params = KMeansParams(k: 3, maxIterations: 200);
      final map = params.toMap();

      expect(map['k'], equals(3));
      expect(map['maxIterations'], equals(200));
      expect(map['initMethod'], equals('k-means++'));
      expect(map['nInit'], equals(10));
      expect(map['tolerance'], equals(1e-4));
    });
  });

  group('HierarchicalParams', () {
    test('has correct defaults', () {
      const params = HierarchicalParams();

      expect(params.linkage, equals('ward'));
      expect(params.distanceThreshold, equals(0.5));
      expect(params.metric, equals('euclidean'));
      expect(params.nClusters, isNull);
    });

    test('toMap() includes nClusters when set', () {
      const params = HierarchicalParams(nClusters: 5);
      final map = params.toMap();

      expect(map, containsPair('nClusters', 5));
    });

    test('toMap() excludes nClusters when null', () {
      const params = HierarchicalParams();
      final map = params.toMap();

      expect(map.containsKey('nClusters'), isFalse);
    });
  });

  group('DimensionReductionConfig', () {
    test('construction with required fields', () {
      const config = DimensionReductionConfig(
        method: 'pca',
        targetDimensions: 50,
      );

      expect(config.method, equals('pca'));
      expect(config.targetDimensions, equals(50));
      expect(config.params, isNull);
    });

    test('toMap() includes params when provided', () {
      const config = DimensionReductionConfig(
        method: 'umap',
        targetDimensions: 20,
        params: {'nNeighbors': 15, 'minDist': 0.1},
      );

      final map = config.toMap();
      expect(map['method'], equals('umap'));
      expect(map['targetDimensions'], equals(20));
      expect(map['params'], isNotNull);
      expect((map['params'] as Map)['nNeighbors'], equals(15));
    });

    test('toMap() excludes params when null', () {
      const config = DimensionReductionConfig(
        method: 'pca',
        targetDimensions: 50,
      );

      final map = config.toMap();
      expect(map.containsKey('params'), isFalse);
    });
  });

  group('ClusteringParams', () {
    test('toMap() includes algorithm and params', () {
      const params = ClusteringParams(
        algorithm: 'dbscan',
        params: {'eps': 0.5, 'minPoints': 5},
      );

      final map = params.toMap();
      expect(map['algorithm'], equals('dbscan'));
      expect(map['params'], isNotNull);
    });

    test('toMap() includes dimensionReduction when present', () {
      const params = ClusteringParams(
        algorithm: 'dbscan',
        params: {'eps': 0.5},
        dimensionReduction: DimensionReductionConfig(
          method: 'pca',
          targetDimensions: 50,
        ),
      );

      final map = params.toMap();
      expect(map.containsKey('dimensionReduction'), isTrue);
    });
  });

  group('selectClusteringParams', () {
    test('selects kmeans when expectedClusters is provided', () {
      final result = selectClusteringParams(
        dataSize: 500,
        dimensions: 10,
        expectedClusters: 5,
      );

      expect(result.algorithm, equals('kmeans'));
      expect(result.params['k'], equals(5));
    });

    test('selects hdbscan for small datasets', () {
      final result = selectClusteringParams(
        dataSize: 500,
        dimensions: 10,
      );

      expect(result.algorithm, equals('hdbscan'));
    });

    test('selects dbscan for large datasets', () {
      final result = selectClusteringParams(
        dataSize: 5000,
        dimensions: 10,
      );

      expect(result.algorithm, equals('dbscan'));
    });

    test('adds dimension reduction for high-dimensional data', () {
      final result = selectClusteringParams(
        dataSize: 5000,
        dimensions: 768,
      );

      expect(result.algorithm, equals('dbscan'));
      expect(result.dimensionReduction, isNotNull);
      expect(result.dimensionReduction!.method, equals('pca'));
      expect(result.dimensionReduction!.targetDimensions, equals(50));
    });

    test('no dimension reduction for low-dimensional data', () {
      final result = selectClusteringParams(
        dataSize: 5000,
        dimensions: 30,
      );

      expect(result.dimensionReduction, isNull);
    });
  });
}
