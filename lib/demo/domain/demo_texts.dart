/// Names used in the demo data (group, machines, steps, notes), in the
/// language of the app when the data is loaded.
class DemoTexts {
  const DemoTexts({
    required this.groupName,
    required this.groupDescription,
    required this.saw,
    required this.bladeChange,
    required this.millingCentre,
    required this.millingSteps,
    required this.chipJam,
    required this.measurePart,
    required this.toolChange,
    required this.washer,
    required this.assembly,
    required this.assemblySteps,
    required this.materialMissing,
    required this.testBench,
    required this.calibration,
    required this.packing,
    required this.changeover,
    required this.changeoverSteps,
  });

  final String groupName;
  final String groupDescription;
  final String saw;
  final String bladeChange;

  /// Name of milling centre n (1-based).
  final String Function(int n) millingCentre;

  /// Four steps of the milling centre.
  final List<String> millingSteps;
  final String chipJam;
  final String measurePart;
  final String toolChange;
  final String washer;
  final String assembly;

  /// Four steps of the assembly.
  final List<String> assemblySteps;
  final String materialMissing;

  /// Name of test bench n (1-based).
  final String Function(int n) testBench;
  final String calibration;
  final String packing;
  final String changeover;

  /// Four steps of the changeover.
  final List<String> changeoverSteps;
}
