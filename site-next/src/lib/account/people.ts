// One member as a row: their photo or initials, name and @username, and
// whatever buttons the page gives them. Text only ever goes in as text.
import { el } from './catalogue';
import { memberName, type Member } from './social';

export function avatar(m: Pick<Member, 'avatarUrl' | 'displayName' | 'username'>, size = 44): HTMLElement {
  const box = el('span', 'avatar');
  box.style.width = box.style.height = `${size}px`;
  box.style.fontSize = `${Math.round(size * 0.38)}px`;
  if (m.avatarUrl) {
    const img = el('img');
    img.src = m.avatarUrl;
    img.alt = '';
    box.append(img);
  } else {
    box.textContent = memberName(m).replace(/^@/, '').split(/\s+/).map((w) => [...w][0] ?? '').join('').slice(0, 2).toUpperCase();
  }
  return box;
}

export function memberRow(m: Member, actions: HTMLElement[] = [], link = true): HTMLLIElement {
  const li = el('li');
  li.classList.add('member-row');
  const who = el('div', 'who');
  const text = el('div');
  const name = el('p', 'saved-name');
  if (link) {
    const a = el('a', undefined, memberName(m));
    a.href = `/account/friend?id=${m.id}`;
    name.append(a);
  } else {
    name.textContent = memberName(m);
  }
  text.append(name);
  if (m.username && m.displayName) text.append(el('p', 'saved-meta', `@${m.username}`));
  who.append(avatar(m), text);
  const buttons = el('div', 'row-actions');
  buttons.append(...actions);
  li.append(who, buttons);
  return li;
}

export function button(label: string, onClick: (b: HTMLButtonElement) => Promise<void> | void, quiet = true): HTMLButtonElement {
  const b = el('button', quiet ? 'button quiet' : 'button', label);
  b.type = 'button';
  b.addEventListener('click', async () => {
    b.disabled = true;
    try {
      await onClick(b);
    } catch {
      b.textContent = 'Try again';
    }
    b.disabled = false;
  });
  return b;
}
