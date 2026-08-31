# Synchronous FIFO Verification Using UVM

## Overview

This project is about verifying a **Synchronous FIFO** using **UVM**.

The FIFO has a single clock and supports read and write operations. The verification environment was built to check the basic FIFO functionality, including writing data, reading data in the correct order, handling `FULL` and `EMPTY` conditions, reset behavior, and checking the design using a reference model and scoreboard.

I also added functional coverage and SystemVerilog assertions to make sure the important FIFO scenarios are covered and the basic FIFO rules are not violated.

---

## FIFO Design

The FIFO is parameterized with:

```text
DATA_WIDTH = 8
DEPTH      = 16
```

So this implementation can store **16 entries**, with each entry being **8 bits wide**.

The FIFO uses:

* Write pointer
* Read pointer
* Memory array
* Counter to keep track of the number of stored entries
* `FULL` flag
* `EMPTY` flag

### Interface

| Signal    | Description             |
| --------- | ----------------------- |
| `clk`     | FIFO clock              |
| `reset`   | Active-high reset       |
| `wr_en`   | Write enable            |
| `rd_en`   | Read enable             |
| `wr_data` | Data written into FIFO  |
| `rd_data` | Data read from FIFO     |
| `full`    | Indicates FIFO is full  |
| `empty`   | Indicates FIFO is empty |

---

## How the FIFO Works

### Write

A write happens when:

```text
wr_en = 1
full  = 0
```

The input data is stored at the current write pointer and the pointer is incremented.

### Read

A read happens when:

```text
rd_en = 1
empty = 0
```

The data at the current read pointer is returned through `rd_data` and the read pointer is incremented.

### Full and Empty

The FIFO keeps track of the number of stored entries using a counter.

```text
count == 0      -> EMPTY
count == DEPTH  -> FULL
```

The read and write pointers wrap around when they reach the end of the FIFO.

---

# UVM Testbench

The verification environment follows the standard UVM structure.

```text
                    +----------------+
                    |   fifo_test    |
                    +-------+--------+
                            |
                            v
                    +----------------+
                    |    fifo_env    |
                    +-------+--------+
                            |
              +-------------+-------------+
              |                           |
              v                           v
       +--------------+             +------------+
       |  fifo_agent  |             | Scoreboard |
       +------+-------+             +------+-----+
              |                            ^
        +-----+-----+                      |
        |           |                      |
        v           v                      |
   Sequencer      Monitor ----------------+
        |
        v
     Driver
        |
        v
       DUT
        |
        +------------------> Monitor
                                  |
                                  v
                              Coverage

                       +------------------+
                       |   SVA Assertions |
                       +------------------+
```

The main UVM components are:

* `fifo_txn`
* `fifo_seq`
* `fifo_sequencer`
* `fifo_driver`
* `fifo_monitor`
* `fifo_agent`
* `fifo_ref_model`
* `fifo_scoreboard`
* `fifo_coverage`
* `fifo_env`
* `fifo_test`

---

## Transaction

The `fifo_txn` class represents a FIFO transaction.

It contains:

```text
reset
wr_en
rd_en
wr_data
rd_data
full
empty
```

`wr_en`, `rd_en`, and `wr_data` are randomized for generating different types of FIFO operations.

The response signals such as `rd_data`, `full`, and `empty` are captured by the monitor.

---

## Sequence

The sequence is not completely random. I used a combination of directed and random transactions so that different FIFO situations can be exercised.

### Write Transactions

First, the sequence forces:

```text
wr_en = 1
rd_en = 0
```

for **20 transactions**.

This gives the FIFO a series of write operations.

### Reset

After the initial writes, reset is applied:

```text
reset = 1
wr_en  = 0
rd_en  = 0
```

Then reset is released.

### Read Transactions

The sequence then forces:

```text
wr_en = 0
rd_en = 1
```

for another **20 transactions**.

### Random Transactions

Finally, **30 completely randomized transactions** are generated.

So the sequence contains:

```text
20 Write transactions
1  Reset transaction
1  Reset release transaction
20 Read transactions
30 Random transactions
```

This gives a total of **72 sequence items**.

---

## Driver

The driver gets transactions from the sequencer and converts them into FIFO interface signals.

The driver also prevents invalid operations from being sent to the DUT:

```text
Write only when FIFO is not full
Read only when FIFO is not empty
```

For example:

```text
wr_en = req.wr_en & !vif.full
rd_en = req.rd_en & !vif.empty
```

The write data is also driven only when a valid write can actually take place.

The driver uses the virtual interface configured through `uvm_config_db`.

---

## Monitor

The monitor continuously observes the FIFO interface using the monitor clocking block.

For every clock cycle it captures:

* Reset
* Write enable
* Read enable
* Write data
* Read data
* Full
* Empty

The captured transaction is then sent through the analysis port to both:

* Scoreboard
* Coverage

---

# Reference Model

The reference model is implemented using a SystemVerilog queue.

```text
fifo_ref_model
       |
       v
  mem_queue[$]
```

The queue represents the expected contents of the FIFO.

### Write

When a valid write occurs:

```text
mem_queue.push_back(wr_data);
```

### Read

When a valid read occurs:

```text
mem_queue.pop_front();
```

The reference model also calculates the expected:

```text
empty
full
```

based on the current queue size.

This gives the scoreboard an independent expected result to compare against the DUT.

---

# Scoreboard

The scoreboard is responsible for checking whether the FIFO is behaving correctly.

It compares the DUT outputs against the reference model.

### Empty Check

```text
Expected EMPTY
      vs
Actual EMPTY
```

### Full Check

```text
Expected FULL
      vs
Actual FULL
```

### Data Check

For a valid read, the expected data is taken from the front of the reference-model queue.

```text
Expected Data
      vs
Actual rd_data
```

If the values match, the scoreboard reports a data match.

If they don't match, a UVM error is generated.

This is especially important for a FIFO because the data must come out in the same order in which it was written.

---

# FIFO Data Order

The reference model uses a queue, so it naturally follows FIFO behavior:

```text
Write:

10 -> 20 -> 30 -> 40

Read:

10 -> 20 -> 30 -> 40
```

The first value written should be the first value read.

This allows the scoreboard to catch issues such as:

* Incorrect read pointer
* Incorrect write pointer
* Data corruption
* Incorrect read ordering
* Incorrect FIFO state

---

# Functional Coverage

Functional coverage is included to make sure the important FIFO operations and conditions are exercised.

The coverage includes:

* Read and write operations
* `FULL` condition
* `EMPTY` condition
* Write enable × FULL combinations
* Read enable × EMPTY combinations

The intention is to make sure the important FIFO scenarios are covered during simulation.

---

# Assertions

Some basic FIFO checks are implemented using SystemVerilog Assertions.

The assertions check things such as:

* Write should not occur when FIFO is full
* Read should not occur when FIFO is empty
* FIFO should not be FULL and EMPTY at the same time
* FIFO should be EMPTY after reset
* Read data should be cleared after reset

These checks help catch basic FIFO functional issues independently of the scoreboard.


# Verification Flow

The overall flow of the testbench is:

```text
        Sequence
           |
           v
      Sequencer
           |
           v
        Driver
           |
           v
          DUT
           |
           v
        Monitor
           |
      +----+----+
      |         |
      v         v
 Scoreboard  Coverage
      |
      v
 Reference
   Model
```

At the same time, the assertion module monitors the FIFO signals for protocol and functional violations.

---

# Scenarios Covered

The testbench exercises the following scenarios:

| Scenario               | Purpose                            |
| ---------------------- | ---------------------------------- |
| Multiple writes        | Check FIFO write operation         |
| Multiple reads         | Check FIFO read operation          |
| Reset                  | Check FIFO initialization          |
| Write after reset      | Check normal operation after reset |
| Read after reset       | Check empty behavior               |
| Random read/write      | Exercise different combinations    |
| Full condition         | Check FIFO full status             |
| Empty condition        | Check FIFO empty status            |
| Read data comparison   | Check FIFO data ordering           |
| Full/Write combination | Covered using functional coverage  |
| Empty/Read combination | Covered using functional coverage  |

---

## EDA Playground Link

The complete APB Slave design and UVM testbench are available on EDA Playground for simulation and verification.

* EDA Playground Link: https://www.edaplayground.com/x/ayEZ

---

# Project Takeaway

This project helped me get more comfortable with the complete UVM flow rather than working with individual UVM components separately.

In particular, I worked with:

* Creating a FIFO transaction
* Generating directed and random sequences
* Connecting sequencer and driver
* Driving a DUT using a virtual interface
* Monitoring DUT activity
* Building a reference model using a queue
* Writing a self-checking scoreboard
* Adding functional coverage
* Writing basic SystemVerilog assertions
* Connecting UVM analysis ports
* Using `uvm_config_db`
* Working with UVM phases and objections

The main thing I wanted to verify was not just whether the FIFO accepts reads and writes, but whether the **data comes out in the correct order and the `FULL`/`EMPTY` status remains consistent with the actual FIFO contents**.
