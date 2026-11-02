#ifndef MINIT_KERNEL_H
#define MINIT_KERNEL_H

/*
 * Kernel entry contract (K1):
 * called from src/boot/start.S with .bss zeroed and a private stack set
 * up. Must never return.
 */

void kmain(void);

#endif /* MINIT_KERNEL_H */
