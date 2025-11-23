# Třída pro řízení studentských projektů
class ProjectManager:
    def __init__(self):
        self.projects = {}
        self.tasks = []
        self.resources = []
    
    def create_project(self, name, description, objectives, timeline):
        """Vytvoření nového projektu podle zásad projektového managementu :cite[2]"""
        project = {
            'name': name,
            'description': description,
            'objectives': objectives,
            'timeline': timeline,
            'status': 'planned',
            'tasks': [],
            'resources': [],
            'milestones': [],
            'risks': []
        }
        self.projects[name] = project
        return project
    
    def add_task(self, project_name, task_name, assignee, deadline):
        """Přidání úkolu do projektu"""
        task = {
            'name': task_name,
            'assignee': assignee,
            'deadline': deadline,
            'status': 'assigned',
            'dependencies': []
        }
        
        if project_name in self.projects:
            self.projects[project_name]['tasks'].append(task)
            self.tasks.append(task)
        return task
    
    def track_progress(self, project_name):
        """Sledování pokroku projektu"""
        if project_name not in self.projects:
            return None
        
        project = self.projects[project_name]
        total_tasks = len(project['tasks'])
        if total_tasks == 0:
            return 0
        
        completed_tasks = sum(1 for task in project['tasks'] if task['status'] == 'completed')
        return (completed_tasks / total_tasks) * 100
    
    def generate_report(self, project_name):
        """Generování reportu o projektu"""
        progress = self.track_progress(project_name)
        report = {
            'project_name': project_name,
            'progress': progress,
            'completed_tasks': [],
            'pending_tasks': [],
            'risks': self.projects[project_name]['risks'],
            'next_milestone': None
        }
        
        for task in self.projects[project_name]['tasks']:
            if task['status'] == 'completed':
                report['completed_tasks'].append(task['name'])
            else:
                report['pending_tasks'].append({
                    'name': task['name'],
                    'assignee': task['assignee'],
                    'deadline': task['deadline']
                })
        
        return report

# Vytvoření instance správce projektů
project_manager = ProjectManager()

# Vytvoření ukázkového projektu
weather_project = project_manager.create_project(
    name="Weather Station IoT",
    description="Měření a vizualizace environmentálních dat",
    objectives=["Sběr dat", "Vizuální zobrazení", "Analýza trendů"],
    timeline="4 týdny"
)

# Přidání úkolů do projektu
project_manager.add_task(
    project_name="Weather Station IoT",
    task_name="Připojení teplotního čidla",
    assignee="Jan Novák",
    deadline="2025-09-20"
)