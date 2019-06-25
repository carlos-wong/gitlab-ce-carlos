// eslint-disable-next-line import/prefer-default-export
export const setTitle = (pathMatch, ref, project) => {
  if (!pathMatch) return;

  const path = pathMatch.replace(/^\//, '');
  const isEmpty = path === '';

  /* eslint-disable-next-line @gitlab/i18n/no-non-i18n-strings */
  document.title = `${isEmpty ? 'Files' : path} · ${ref} · ${project}`;
};
