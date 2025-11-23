# Třída pro hodnocení studentských projektů
class ProjectEvaluator:
    def __init__(self):
        self.evaluation_criteria = {
            'functionality': 0.3,
            'code_quality': 0.2,
            'documentation': 0.15,
            'creativity': 0.15,
            'presentation': 0.2
        }
    
    def evaluate_project(self, project, submission):
        """Komplexní vyhodnocení projektu podle stanovených kritérií"""
        scores = {}
        
        # Hodnocení funkčnosti
        scores['functionality'] = self.evaluate_functionality(project, submission)
        
        # Hodnocení kvality kódu
        scores['code_quality'] = self.evaluate_code_quality(submission['code'])
        
        # Hodnocení dokumentace
        scores['documentation'] = self.evaluate_documentation(submission['documentation'])
        
        #