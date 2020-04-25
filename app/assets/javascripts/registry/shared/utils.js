export const findDefaultOption = options => {
  const item = options.find(o => o.default);
  return item ? item.key : null;
};

export const mapComputedToEvent = (list, root) => {
  const result = {};
  list.forEach(e => {
    result[e] = {
      get() {
        return this[root][e];
      },
      set(value) {
        this.$emit('input', { ...this[root], [e]: value });
      },
    };
  });
  return result;
};
