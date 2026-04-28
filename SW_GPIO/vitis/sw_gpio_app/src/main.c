#include "xgpio.h"
#include "xparameters.h"
#include "xstatus.h"

#define GPIO_CTRL_BASEADDR     XPAR_AXI_GPIO_CTRL_BASEADDR
#define GPIO_BUTTONS_BASEADDR  XPAR_AXI_GPIO_BUTTONS_BASEADDR
#define GPIO_STATUS_BASEADDR   XPAR_AXI_GPIO_STATUS_BASEADDR

#define GPIO_CH                1U
#define CMD_RUN                0x1U
#define CMD_STOP               0x2U

#define BTN_STOP_MASK          0x1U
#define BTN_RUN_MASK           0x2U
#define STATUS_BCD_MASK        0x0000FFFFU
#define STATUS_RUN_MASK        0x00010000U
#define STATUS_ROLLOVER_MASK   0x00020000U

static XGpio GpioCtrl;
static XGpio GpioButtons;
static XGpio GpioStatus;
static volatile unsigned int LastStatus;

static void small_delay(void)
{
    volatile unsigned int idx;

    for (idx = 0; idx < 10000U; idx++) {
        /* keep the GPIO pulse visible to the fabric */
    }
}

static void send_command(unsigned int cmd)
{
    XGpio_DiscreteWrite(&GpioCtrl, GPIO_CH, cmd);
    small_delay();
    XGpio_DiscreteWrite(&GpioCtrl, GPIO_CH, 0U);
    small_delay();
}

int main(void)
{
    int status;
    unsigned int buttons;
    unsigned int buttons_prev = 0U;
    unsigned int buttons_pressed;

    status = XGpio_Initialize(&GpioCtrl, GPIO_CTRL_BASEADDR);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    status = XGpio_Initialize(&GpioButtons, GPIO_BUTTONS_BASEADDR);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    status = XGpio_Initialize(&GpioStatus, GPIO_STATUS_BASEADDR);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    XGpio_SetDataDirection(&GpioCtrl, GPIO_CH, 0x0U);
    XGpio_SetDataDirection(&GpioButtons, GPIO_CH, 0xFFFFFFFFU);
    XGpio_SetDataDirection(&GpioStatus, GPIO_CH, 0xFFFFFFFFU);
    XGpio_DiscreteWrite(&GpioCtrl, GPIO_CH, 0U);

    while (1) {
        buttons = XGpio_DiscreteRead(&GpioButtons, GPIO_CH) & (BTN_RUN_MASK | BTN_STOP_MASK);
        buttons_pressed = buttons & ~buttons_prev;

        if ((buttons_pressed & BTN_RUN_MASK) != 0U) {
            send_command(CMD_RUN);
        }

        if ((buttons_pressed & BTN_STOP_MASK) != 0U) {
            send_command(CMD_STOP);
        }

        buttons_prev = buttons;
        LastStatus = XGpio_DiscreteRead(&GpioStatus, GPIO_CH);
        small_delay();
    }

    return XST_SUCCESS;
}
