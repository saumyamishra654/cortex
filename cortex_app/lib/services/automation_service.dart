import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AutomationResult {
  final bool success;
  final String output;
  final String? error;

  AutomationResult({required this.success, required this.output, this.error});
}

class AutomationService {
  static Future<String?> findProjectRoot() async {
    Directory current = Directory.current;
    debugPrint('AutomationService: Starting root search from ${current.path}');
    
    // Search up for project root
    for (int i = 0; i < 10; i++) {
       // Look for the specific setup script to confirm this is the right folder
       final setupScript = File(p.join(current.path, 'scripts', 'setup_cortex_service.sh'));
       if (await setupScript.exists()) {
         debugPrint('AutomationService: Found project root at ${current.path}');
         return current.path;
       }
       
       // Also check if we are inside cortex_app (common in dev)
       if (p.basename(current.path) == 'cortex_app') {
         final parentRoot = current.parent;
         final parentSetup = File(p.join(parentRoot.path, 'scripts', 'setup_cortex_service.sh'));
         if (await parentSetup.exists()) {
           debugPrint('AutomationService: Found project root via parent at ${parentRoot.path}');
           return parentRoot.path;
         }
       }
       
       final parent = current.parent;
       if (parent.path == current.path) break;
       current = parent;
    }
    
    debugPrint('AutomationService: ERROR: Could not find project root in 10 levels.');
    return null;
  }

  static Future<AutomationResult> installMacosService() async {
    try {
      final root = await findProjectRoot();
      if (root == null) {
        return AutomationResult(
          success: false, 
          output: '', 
          error: 'Could not locate project root or scripts folder.'
        );
      }

      final scriptPath = p.join(root, 'scripts', 'setup_cortex_service.sh');
      
      // Ensure it's executable
      await Process.run('chmod', ['+x', scriptPath]);
      
      final result = await Process.run('bash', [scriptPath]);
      
      return AutomationResult(
        success: result.exitCode == 0,
        output: result.stdout.toString(),
        error: result.exitCode == 0 ? null : result.stderr.toString(),
      );
    } catch (e) {
      return AutomationResult(success: false, output: '', error: e.toString());
    }
  }
}
