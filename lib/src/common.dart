extension Apply<T> on T {
  T apply(Function(T) fun) {
    fun(this);
    return this;
  }
}
