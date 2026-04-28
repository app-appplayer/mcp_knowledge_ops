/// Clustering - Algorithm parameter models and adaptive selection.
///
/// Implements the clustering configuration models and adaptive parameter
/// selection algorithm from the pipelines spec section 7.1 for the
/// PatternMiningPipeline's cluster_signals stage.
library;

/// Top-level clustering configuration combining algorithm choice,
/// parameters, and optional dimension reduction.
class ClusteringParams {
  /// Algorithm name: 'dbscan', 'hdbscan', 'kmeans', 'hierarchical'.
  final String algorithm;

  /// Algorithm-specific parameters as a flat map.
  final Map<String, dynamic> params;

  /// Optional dimension reduction configuration for high-dimensional data.
  final DimensionReductionConfig? dimensionReduction;

  const ClusteringParams({
    required this.algorithm,
    required this.params,
    this.dimensionReduction,
  });

  Map<String, dynamic> toMap() => {
        'algorithm': algorithm,
        'params': params,
        if (dimensionReduction != null)
          'dimensionReduction': dimensionReduction!.toMap(),
      };
}

/// DBSCAN parameters per spec section 7.1.
///
/// Best for fixed-density clusters with noise.
/// Complexity: O(n^2) without spatial index, O(n log n) with index.
class DBSCANParams {
  /// Maximum distance between two points to be considered neighbors.
  final double eps;

  /// Minimum points to form a dense region (core point).
  final int minPoints;

  /// Distance metric: 'euclidean', 'cosine', 'manhattan', 'jaccard'.
  final String metric;

  /// Use spatial index for efficiency on large datasets.
  final bool useSpatialIndex;

  const DBSCANParams({
    this.eps = 0.5,
    this.minPoints = 5,
    this.metric = 'cosine',
    this.useSpatialIndex = false,
  });

  Map<String, dynamic> toMap() => {
        'eps': eps,
        'minPoints': minPoints,
        'metric': metric,
        'useSpatialIndex': useSpatialIndex,
      };
}

/// HDBSCAN parameters per spec section 7.1.
///
/// Best for variable density clusters, unknown number of clusters.
/// Complexity: O(n^2) for distance matrix, O(n log n) for hierarchy.
class HDBSCANParams {
  /// Minimum size for a cluster to be considered valid.
  final int minClusterSize;

  /// Similar to DBSCAN's minPts for core points.
  final int minSamples;

  /// Distance metric: 'euclidean', 'cosine', 'manhattan', 'jaccard'.
  final String metric;

  /// Cluster selection method: 'eom' (Excess of Mass) or 'leaf'.
  final String clusterSelectionMethod;

  /// Merge clusters closer than this threshold (0 = no merging).
  final double clusterSelectionEpsilon;

  /// Allow single-point clusters.
  final bool allowSingleCluster;

  const HDBSCANParams({
    this.minClusterSize = 5,
    this.minSamples = 3,
    this.metric = 'cosine',
    this.clusterSelectionMethod = 'eom',
    this.clusterSelectionEpsilon = 0.0,
    this.allowSingleCluster = false,
  });

  Map<String, dynamic> toMap() => {
        'minClusterSize': minClusterSize,
        'minSamples': minSamples,
        'metric': metric,
        'clusterSelectionMethod': clusterSelectionMethod,
        'clusterSelectionEpsilon': clusterSelectionEpsilon,
        'allowSingleCluster': allowSingleCluster,
      };
}

/// K-Means parameters per spec section 7.1.
///
/// Best for known number of clusters with spherical shape.
/// Complexity: O(n * k * i * d) where i = iterations.
class KMeansParams {
  /// Number of clusters.
  final int k;

  /// Maximum convergence iterations.
  final int maxIterations;

  /// Centroid initialization method: 'random' or 'kmeans++'.
  final String initMethod;

  /// Number of runs with different initializations.
  final int nInit;

  /// Convergence tolerance for early stopping.
  final double tolerance;

  const KMeansParams({
    required this.k,
    this.maxIterations = 100,
    this.initMethod = 'k-means++',
    this.nInit = 10,
    this.tolerance = 1e-4,
  });

  Map<String, dynamic> toMap() => {
        'k': k,
        'maxIterations': maxIterations,
        'initMethod': initMethod,
        'nInit': nInit,
        'tolerance': tolerance,
      };
}

/// Hierarchical clustering parameters per spec section 7.1.
///
/// Best for exploratory analysis and hierarchical relationships.
/// Complexity: O(n^3) for naive, O(n^2 log n) for optimized.
class HierarchicalParams {
  /// Linkage method: 'single', 'complete', 'average', 'ward'.
  final String linkage;

  /// Threshold to cut dendrogram for flat cluster extraction.
  final double distanceThreshold;

  /// Distance metric: 'euclidean', 'cosine', 'manhattan'.
  final String metric;

  /// Target number of clusters (alternative to distanceThreshold).
  final int? nClusters;

  const HierarchicalParams({
    this.linkage = 'ward',
    this.distanceThreshold = 0.5,
    this.metric = 'euclidean',
    this.nClusters,
  });

  Map<String, dynamic> toMap() => {
        'linkage': linkage,
        'distanceThreshold': distanceThreshold,
        'metric': metric,
        if (nClusters != null) 'nClusters': nClusters,
      };
}

/// Dimension reduction configuration for high-dimensional signal data.
///
/// Signal embeddings (from LLM or feature extraction) can be 768+
/// dimensions. Dimension reduction improves clustering quality and
/// performance.
class DimensionReductionConfig {
  /// Reduction technique: 'pca', 'umap', 'tsne', 'random_projection'.
  final String method;

  /// Target dimensionality after reduction.
  final int targetDimensions;

  /// Method-specific parameters (e.g. UMAP nNeighbors, minDist).
  final Map<String, dynamic>? params;

  const DimensionReductionConfig({
    required this.method,
    required this.targetDimensions,
    this.params,
  });

  Map<String, dynamic> toMap() => {
        'method': method,
        'targetDimensions': targetDimensions,
        if (params != null) 'params': params,
      };
}

/// Adaptive clustering parameter selection per spec section 7.1.
///
/// Automatically selects an appropriate algorithm and parameters
/// based on data characteristics such as dataset size, dimensionality,
/// and whether the expected number of clusters is known.
ClusteringParams selectClusteringParams({
  required int dataSize,
  required int dimensions,
  int? expectedClusters,
}) {
  // If the expected number of clusters is known, use K-Means.
  if (expectedClusters != null) {
    return ClusteringParams(
      algorithm: 'kmeans',
      params: KMeansParams(k: expectedClusters).toMap(),
    );
  }

  // For small datasets use HDBSCAN (variable density handling).
  if (dataSize < 1000) {
    return ClusteringParams(
      algorithm: 'hdbscan',
      params: const HDBSCANParams().toMap(),
    );
  }

  // For larger datasets use DBSCAN with optional dimension reduction.
  return ClusteringParams(
    algorithm: 'dbscan',
    params: const DBSCANParams().toMap(),
    dimensionReduction: dimensions > 50
        ? DimensionReductionConfig(method: 'pca', targetDimensions: 50)
        : null,
  );
}
