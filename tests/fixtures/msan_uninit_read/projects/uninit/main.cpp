// MSan: branches on a heap value nothing initialized.
int main(int argc, char**) {
  int* values = new int[4];
  const int value = values[argc];
  delete[] values;
  return value == 0 ? 0 : 1;
}
