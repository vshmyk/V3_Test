import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () => import('./core/core-console.component').then(m => m.CoreConsoleComponent)
  },
  {
    path: 'rhumbix',
    loadComponent: () => import('./rhumbix/rhumbix-integration.component').then(m => m.RhumbixIntegrationComponent)
  },
  {
    path: 'payroll',
    loadComponent: () => import('./payroll/payroll-console.component').then(m => m.PayrollConsoleComponent)
  }
];
