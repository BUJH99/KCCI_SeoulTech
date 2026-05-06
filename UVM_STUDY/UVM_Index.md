1. Def of uvm
   - universal verification methodology
   - Reusable Verification Framework

2. Interface
   - Clocking Block
   - Diff [Mon / DRV]

3. Item : Modeling a Bus Using a Class
   - Object
   - uvm_void ➔ uvm_object ➔ uvm_transaction ➔ uvm_sequence_item
   - Factory : Use to Overrid, Use to Expanding transaction Class
   - uvm_object_utils : Use to Factory
   - uvm_field_int : Use to `copy()`, `compare()`, `print()`, `pack()`, `unpack()`
   - uvm_all_on : Apply library configuration to variables.
   - super : Apply to Parents class Set as is
   - OverRide : Diff to new() -> Needs Modifi : new =  Direct Edit / Factory = Overwrite for using a Create
   - constraint : Global Rule
   - modport : Limit Signal Direction for DRV / MON

4. Sequence : Make a Transaction
   - Object
   - #(item) : [a]. Class Proper Set like Ctrl + H
               [b]. Type Decision for Variable
               [c]. Type Safety in Compile Step
   - Task body() : Main Scenario
   *Basic Pattern
   - item = ItemType::type_id::create("item");
   - start_item(item) : Ready for Transfer the Trasaction to the Sequencer
   - item.randomize() : Detiermines the contents of Transaction
   - finish_item(item) : Transfers the transaction to the driver
   - constraint : Local Rule in specific Seqeunce

5. Driver : Transfer From Sw to HW
   - Component
   - Active
   - Receive a tr from Sequence
   - Diff [Virtual IF vs IF] : Connenct Timing
   - uvm_phase phase : Phase Object
   - build Phase : Get to cf_db
   - config_db : Global DB of UVM
   - uvm_config_db#(virtual Top_If)::get(this, "", "vif", vif)
   - #(Type)::get(Req Component, Ins Route, Data key name, Store to Variable)
   - uvm message Level : `uvm_info /`uvm_warning /`uvm_error /`uvm_fatal
   - run Phase : Communication [TLM] + use to HW Rule
   - seq_item_port : TLM Port - [Driver <-> Sequencer]  
   - seq_item_port.get_next_item(tr)
   - seq_item_port.item_done()

6. Monitor : Transfer From Hw to SW
   - Component
   - Active, Passive
   - uvm_analysis_port : Transnfer Data to Scoreboard, coverage collector
   - Diff [seq_item_port vs ap]
   - build_phase : reuse
   - run_phase : Monitoring Logic
   - Look at the signal -> Make a new tr
   - ap.write(tr) : Transger to Other Component

7. Sequencer : Middle Route
   - Component
   - Active
   - Sequence → Sequencer → Driver

8. Agent : Integrated management of Sequencer, Driver, and Monitor
   - Agent Component : Sequencer, Driver, Monitor
   - enum is_active : Active or Passive
   - build_phase : create Sequencer, Driver, Monitor
   - connect_phase : connect, TLM Export

9. Scoreboard : Compare [Golden vs Real]
   - Component
   - uvm_analysis_port : Receive Data from Monitor
   - build_phase : Golden Logic Initial Setup
   - write function : write[make a golden] / read[compare]

10. Coverage : Check Verification Completeness
   - Component
   - uvm_subscriber
   - Functional Coverage
   - covergroup : coverpoint, bins, cross
   - coverpoint : {bins, illegal_bins, ignore_bins } = Rule & Detail coverpoint / * iff -> sample condition
   - cross : cross cp1, cp2
   - cg = new();
   - write function : Data mapping, sample() - caputure, uvm log
   - report_phase : Print Coverage Result

11. Env : Integrated management of Agent, Scoreboard, Coverage
   - Component
   - build_phase : create Agent, Scoreboard, Coverage
   - connect_phase : connect [Agent + Scoreboard]
   - TLM Rule : Sendport.connect.(Receiveport)

12. Test : Top Scenario Controller
   - Component
   - build_phase : Create Env
   - Select Verification Scenario
   - run_phase : Objection Mechanism, Create Seq, Seq Start
   - Objection Mechanism : phase.raise.objection / phase.drop.objecion
   - Factory Override : Change Item / Sequence / Component without Direct Edit
   * Test build_phase [order of Ex]
      [0] test.build_phase() : create Seqeunce, Env
      [1] env.build_phase() : create Scorebaord, Agent
      [2] scorebaord.build_phase() : create Transaction
      [3] agent.build_phase() : create Driver, Monitor, Sequencer
      [4] drive.build_phase() : connect Transacion, Interface
      [5] monitor.build_phase() : connect Transaction, Interface

13. Package : Package for Uvm Class
   - package
   - import uvm_pkg::*;
   - `include "uvm_macros.svh"
   - `include "Component"

14. tb_Top : TB_MODULE
   - Module
   - Instance : IF, Src, Assertions
   - initial run_test();
   - config_db::set() : Send virtual interface to UVM Component

15. SystemVerilog Assertion : Signal-Level Protocol Checker
   - Module
   - property : Defines the rules
   - assert proeprty : Outputs an error if a rule is violated.
   - cover property : sva coverage 

16. UVM Phase : Simulation Execution Order
   - build_phase : Create Component
   - connect_phase : Connect TLM Port
   - run_phase : Main Verification Operation
   - check_phase : Final Data Check
   - report_phase : Print Final Result