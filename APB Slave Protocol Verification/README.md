# APB Slave Protocol Verification Using UVM

## Overview

This project is a UVM-based verification environment developed to verify an **APB Slave** using UVM.

The main goal of this project was to understand how a complete UVM testbench is built around a bus protocol and how different UVM components work together to generate, drive, monitor, and check APB transactions.

The testbench covers normal read/write operations, invalid address accesses, wait states, error responses, functional coverage, and a few basic APB protocol checks using assertions.

---

## About APB

APB (Advanced Peripheral Bus) is a simple, low-power bus protocol used for connecting peripherals such as control registers, timers, UARTs, GPIOs, etc.

An APB transfer happens in two phases:

* **SETUP phase** – `PSEL` is asserted and `PENABLE` is low.
* **ACCESS phase** – `PENABLE` goes high and the transfer completes when `PREADY` is asserted.

For this project, the slave also supports wait states, so `PREADY` does not have to go high immediately during the ACCESS phase.

---

## DUT

The DUT is an APB Slave with four registers.

| Address | Register | Access       |
| ------- | -------- | ------------ |
| `8'h00` | CTRL     | Read / Write |
| `8'h04` | STATUS   | Read         |
| `8'h08` | DATA     | Read / Write |
| `8'h0C` | VERSION  | Read         |

The slave is parameterized with:

```text
ADDR_WIDTH  = 8
DATA_WIDTH  = 8
WAIT_STATES = 2
```

The `STATUS` and `VERSION` registers are read-only. A write to these registers is treated as an error and `PSLVERR` is asserted.

Invalid addresses are also treated as error accesses.

---

## UVM Testbench

The testbench follows the usual UVM structure:

```text
                 APB Test
                    |
                    v
                 APB Env
                    |
             +------+------+
             |             |
             v             v
          APB Agent    Scoreboard
             |
       +-----+-----+
       |           |
       v           v
   Sequencer     Monitor
       |
       v
     Driver
       |
       v
      DUT
       |
       +-----------> Monitor
                         |
                 +-------+-------+
                 |               |
                 v               v
             Scoreboard      Coverage
```

The main components are:

* Sequence Item
* Sequence
* Sequencer
* Driver
* Monitor
* Agent
* Environment
* Reference Model
* Scoreboard
* Coverage
* Assertions
* Test

---

## Sequence Item

The APB transaction is represented using a UVM sequence item.

It contains the information required to perform and monitor an APB transfer, including:

* Address
* Read/Write control
* Write data
* Read data
* `PREADY`
* `PSLVERR`

The transaction is randomized where required so that different APB accesses can be generated during simulation.

---

## Sequence

The sequence generates different types of transactions instead of depending only on completely random stimulus.

### Valid Address Transactions

20 transactions are generated using the valid register addresses:

```text
8'h00
8'h04
8'h08
8'h0C
```

### Invalid Address Transactions

20 transactions are generated using addresses outside the implemented register map.

These accesses are expected to result in an APB error.

### Random Transactions

Another 50 transactions are generated with randomized APB fields.

So the sequence generates a total of:

```text
20 Valid
20 Invalid
50 Random
----------------
90 Transactions
```

This gives a combination of directed and random testing.

---

## Driver

The driver converts the transaction received from the sequencer into APB signals.

For each transaction, it drives the APB SETUP phase first and then moves to the ACCESS phase.

The driver waits for `PREADY` before considering the transaction complete.

This is important for this design because the slave can insert wait states.

---

## Monitor

The monitor observes the APB interface and collects completed transfers.

A transaction is sampled when the APB transfer reaches the completion condition:

```text
PSEL    = 1
PENABLE = 1
PREADY  = 1
```

The monitor sends the collected transaction to the scoreboard and coverage components through the UVM analysis mechanism.

---

## Reference Model and Scoreboard

The reference model keeps track of the expected register values and predicts the expected response from the slave.

The scoreboard receives the actual transaction from the monitor and compares it with the expected result from the reference model.

For a read transaction, the main comparison is:

```text
Expected PRDATA
        |
        | compare
        v
Actual PRDATA
```

The scoreboard also checks `PSLVERR`.

For example:

* Reading a valid register → no error
* Writing CTRL → no error
* Writing DATA → no error
* Writing STATUS → error
* Writing VERSION → error
* Accessing an invalid address → error

This makes the testbench self-checking rather than relying only on waveform inspection.

---

## Functional Coverage

Functional coverage is included to keep track of which parts of the design have been exercised.

The coverage includes:

* Read and write transactions
* Register addresses
* Error responses
* Read data
* Address × Read/Write combinations
* Read/Write × Error combinations
* Address × Error combinations

The intention is to make sure that the important combinations of APB accesses are actually being tested.

---

## Assertions

Some basic APB protocol checks are implemented using SystemVerilog Assertions.

The assertions check things such as:

* SETUP phase is followed by ACCESS phase
* `PENABLE` should not be asserted without `PSEL`
* `PREADY` should only be asserted during ACCESS
* `PSLVERR` should only be asserted when the transfer is ready
* Writes to read-only registers should generate an error
* VERSION register should return the expected value

These checks help catch protocol-related issues independently of the scoreboard.

---

## Wait State Handling

The slave is configured with:

```text
WAIT_STATES = 2
```

During the wait period, the slave keeps `PREADY` low.

Once the required number of cycles has passed, `PREADY` is asserted and the transfer completes.

This was included to make the testbench handle something closer to a real peripheral response instead of testing only zero-wait-state transfers.

---

## What I Verified

The main scenarios covered in this project are:

| Test Scenario         | Expected Behavior     |
| --------------------- | --------------------- |
| CTRL write            | Successful transfer   |
| CTRL read             | Returns stored value  |
| STATUS read           | Successful read       |
| STATUS write          | `PSLVERR` asserted    |
| DATA write            | Successful transfer   |
| DATA read             | Returns stored value  |
| VERSION read          | Returns `8'h01`       |
| VERSION write         | `PSLVERR` asserted    |
| Invalid address read  | Error response        |
| Invalid address write | Error response        |
| Wait-state transfer   | `PREADY` delayed      |
| Random APB accesses   | Checked by scoreboard |

---

## EDA Playground Link

The complete APB Slave design and UVM testbench are available on EDA Playground for simulation and verification.

* EDA Playground Link: https://www.edaplayground.com/x/gwfB

---

## UVM Concepts Used

While working on this project, I used the following UVM concepts:

* `uvm_sequence_item`
* `uvm_sequence`
* `uvm_sequencer`
* `uvm_driver`
* `uvm_monitor`
* `uvm_agent`
* `uvm_env`
* `uvm_test`
* `uvm_scoreboard`
* `uvm_subscriber`
* Analysis ports
* `uvm_config_db`
* Virtual interface
* Factory mechanism
* UVM phases
* Objections
* Constrained randomization

---

## Project Takeaway

The main purpose of this project was not just to verify an APB slave, but to get comfortable with building a UVM environment from scratch.

The project helped me understand how a transaction moves through the UVM testbench:

```text
Sequence
   ↓
Sequencer
   ↓
Driver
   ↓
DUT
   ↓
Monitor
   ↓
Scoreboard
```

Along with the basic UVM flow, I also got hands-on experience with functional coverage, reference-model-based checking, wait-state handling, and SystemVerilog assertions.
