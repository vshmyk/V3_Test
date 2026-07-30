import { Directive, ElementRef, HostListener, inject } from '@angular/core';

@Directive({
  selector: '[appArrowFieldNavigation]',
  standalone: true
})
export class ArrowFieldNavigationDirective {
  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);

  @HostListener('focusin', ['$event'])
  onFocusIn(event: FocusEvent): void {
    const target = event.target;
    if (!this.isAutoSelectField(target)) {
      return;
    }

    requestAnimationFrame(() => target.select());
  }

  @HostListener('keydown', ['$event'])
  onKeyDown(event: KeyboardEvent): void {
    if (event.key === 'ArrowRight' && !event.altKey && !event.ctrlKey && !event.metaKey && !event.shiftKey) {
      if (event.target instanceof HTMLElement && event.target.closest('.legacy-lookup-combobox')) {
        return;
      }

      this.focusLookupDropdown(event);
      return;
    }

    if (event.key === 'ArrowLeft' && !event.altKey && !event.ctrlKey && !event.metaKey && !event.shiftKey) {
      this.focusLookupInput(event);
      return;
    }

    if ((event.key === 'ArrowDown' || event.key === 'ArrowUp') && this.moveWithinLookupOptions(event)) {
      return;
    }

    if ((event.key !== 'ArrowDown' && event.key !== 'ArrowUp') || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) {
      return;
    }

    const target = event.target;
    if (!(target instanceof HTMLElement) || !this.isNavigableField(target)) {
      return;
    }

    const fields = this.navigableFields();
    const currentIndex = fields.indexOf(target);
    if (currentIndex < 0) {
      return;
    }

    const direction = event.key === 'ArrowDown' ? 1 : -1;
    const next = fields[currentIndex + direction];
    if (!next) {
      return;
    }

    event.preventDefault();
    next.focus({ preventScroll: true });
    next.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }

  private navigableFields(): HTMLElement[] {
    return Array.from(this.host.nativeElement.querySelectorAll<HTMLElement>('input, textarea, select'))
      .filter(field => this.isNavigableField(field));
  }

  private focusLookupDropdown(event: KeyboardEvent): void {
    const target = event.target;
    if (!(target instanceof HTMLElement) || !this.isNavigableField(target)) {
      return;
    }

    const combobox = target.closest<HTMLElement>('.legacy-lookup-combobox');
    if (!combobox) {
      return;
    }

    const toggle = combobox.querySelector<HTMLButtonElement>('.legacy-lookup-toggle');
    if (!toggle || toggle.disabled) {
      return;
    }

    event.preventDefault();
    const currentOption = combobox.querySelector<HTMLButtonElement>('.legacy-lookup-option');
    if (!currentOption) {
      toggle.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, view: window }));
    }

    requestAnimationFrame(() => {
      const option = combobox.querySelector<HTMLButtonElement>('.legacy-lookup-option');
      (option ?? toggle).focus({ preventScroll: true });
      (option ?? toggle).scrollIntoView({ block: 'nearest', inline: 'nearest' });
    });
  }

  private focusLookupInput(event: KeyboardEvent): void {
    const target = event.target;
    if (!(target instanceof HTMLElement) || !target.classList.contains('legacy-lookup-option')) {
      return;
    }

    const combobox = target.closest<HTMLElement>('.legacy-lookup-combobox');
    const input = combobox?.querySelector<HTMLInputElement>('input');
    if (!input) {
      return;
    }

    event.preventDefault();
    input.focus({ preventScroll: true });
  }

  private moveWithinLookupOptions(event: KeyboardEvent): boolean {
    const target = event.target;
    if (!(target instanceof HTMLElement) || !target.classList.contains('legacy-lookup-option')) {
      return false;
    }

    const combobox = target.closest<HTMLElement>('.legacy-lookup-combobox');
    const options = Array.from(combobox?.querySelectorAll<HTMLButtonElement>('.legacy-lookup-option') ?? []);
    const currentIndex = options.indexOf(target as HTMLButtonElement);
    if (currentIndex < 0) {
      return false;
    }

    const direction = event.key === 'ArrowDown' ? 1 : -1;
    const next = options[currentIndex + direction];
    if (!next) {
      if (event.key === 'ArrowUp' && currentIndex === 0) {
        this.focusLookupInput(event);
        return true;
      }

      return false;
    }

    event.preventDefault();
    next.focus({ preventScroll: true });
    next.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    return true;
  }

  private isNavigableField(field: HTMLElement): boolean {
    if (field.hasAttribute('disabled') || field.getAttribute('tabindex') === '-1') {
      return false;
    }

    if (field instanceof HTMLInputElement && field.type === 'hidden') {
      return false;
    }

    if (field.closest('[hidden], [aria-hidden="true"], .legacy-lookup-panel')) {
      return false;
    }

    return this.isVisible(field);
  }

  private isVisible(field: HTMLElement): boolean {
    const style = window.getComputedStyle(field);
    return style.display !== 'none' && style.visibility !== 'hidden' && field.offsetParent !== null;
  }

  private isAutoSelectField(field: EventTarget | null): field is HTMLInputElement | HTMLTextAreaElement {
    if (field instanceof HTMLTextAreaElement) {
      return !field.readOnly && this.isNavigableField(field);
    }

    if (!(field instanceof HTMLInputElement) || !this.isNavigableField(field)) {
      return false;
    }

    if (field.readOnly) {
      return false;
    }

    return ['text', 'number', 'email', 'tel', 'url', 'search', 'password'].includes(field.type);
  }
}
