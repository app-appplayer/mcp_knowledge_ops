/// Tests for concrete workflows: SkillBuild, ProfileBuild, BundleBuild.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('SkillBuildWorkflow', () {
    test('construction with defaults', () {
      final workflow = SkillBuildWorkflow();

      expect(workflow.id, equals('skill_build'));
      expect(workflow.name, equals('Skill Build Workflow'));
      expect(workflow.version, equals('1.0.0'));
      expect(workflow.description, isNotNull);
    });

    test('custom id is accepted', () {
      final workflow = SkillBuildWorkflow(id: 'custom_skill_build');

      expect(workflow.id, equals('custom_skill_build'));
    });

    test('stages is non-empty', () {
      final workflow = SkillBuildWorkflow();

      expect(workflow.stages, isNotEmpty);
      expect(workflow.stages.length, greaterThanOrEqualTo(5));
    });

    test('gates list is populated', () {
      final workflow = SkillBuildWorkflow();

      expect(workflow.gates, isNotEmpty);
      expect(workflow.gates.first.id, equals('eval_pass'));
    });

    test('config defaults', () {
      final workflow = SkillBuildWorkflow();

      expect(workflow.config.autoApprove, isFalse);
      expect(workflow.config.dryRun, isFalse);
    });

    test('SkillBuildInput creation', () {
      const input = SkillBuildInput(
        patternId: 'pattern-1',
        skillName: 'MySkill',
        version: '1.0.0',
        publishTarget: 'staging',
      );

      expect(input.patternId, equals('pattern-1'));
      expect(input.skillName, equals('MySkill'));
      expect(input.version, equals('1.0.0'));
      expect(input.publishTarget, equals('staging'));
    });
  });

  group('ProfileBuildWorkflow', () {
    test('construction with defaults', () {
      final workflow = ProfileBuildWorkflow();

      expect(workflow.id, equals('profile_build'));
      expect(workflow.name, equals('Profile Build Workflow'));
      expect(workflow.version, equals('1.0.0'));
    });

    test('stages is non-empty', () {
      final workflow = ProfileBuildWorkflow();

      expect(workflow.stages, isNotEmpty);
      expect(workflow.stages.length, greaterThanOrEqualTo(5));
    });

    test('gates list is populated', () {
      final workflow = ProfileBuildWorkflow();

      expect(workflow.gates, isNotEmpty);
    });

    test('ProfileBuildInput creation', () {
      const input = ProfileBuildInput(
        source: 'pattern',
        patternId: 'pattern-1',
        version: '1.0.0',
        publishTarget: 'draft',
      );

      expect(input.source, equals('pattern'));
      expect(input.patternId, equals('pattern-1'));
      expect(input.profileDef, isNull);
    });

    test('ProfileBuildInput with manual source', () {
      const input = ProfileBuildInput(
        source: 'manual',
        profileDef: ProfileDefinition(
          name: 'Test Profile',
          policies: {'key': 'value'},
        ),
      );

      expect(input.source, equals('manual'));
      expect(input.profileDef, isNotNull);
      expect(input.profileDef!.name, equals('Test Profile'));
    });
  });

  group('BundleBuildWorkflow', () {
    test('construction with defaults', () {
      final workflow = BundleBuildWorkflow();

      expect(workflow.id, equals('bundle_build'));
      expect(workflow.name, equals('Bundle Build Workflow'));
      expect(workflow.version, equals('1.0.0'));
    });

    test('stages is non-empty', () {
      final workflow = BundleBuildWorkflow();

      expect(workflow.stages, isNotEmpty);
      expect(workflow.stages.length, greaterThanOrEqualTo(5));
    });

    test('gates list is populated', () {
      final workflow = BundleBuildWorkflow();

      expect(workflow.gates, isNotEmpty);
    });

    test('BundleBuildInput creation', () {
      const input = BundleBuildInput(
        manifestId: 'manifest-1',
        components: BundleComponents(
          skillIds: ['skill-1', 'skill-2'],
          profileIds: ['profile-1'],
        ),
        version: '1.0.0',
        publishTarget: 'production',
      );

      expect(input.manifestId, equals('manifest-1'));
      expect(input.components.skillIds, hasLength(2));
      expect(input.components.profileIds, hasLength(1));
      expect(input.publishTarget, equals('production'));
    });
  });
}
