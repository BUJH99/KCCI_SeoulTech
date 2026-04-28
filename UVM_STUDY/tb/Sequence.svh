class Top_Seq extends uvm_sequence #(Top_Item);
    `uvm_object_utils(Top_Seq)

    function new(string name = "Top_Seq");
        super.new(name);
    endfunction

    // Libarary : task body() = Main Scenario
    task body();
        Top_Item t;

        repeat (20) begin
            // ClassName::type_id::create("InstacneName")
            t = Top_Item::type_id::create("t");

            //Blocking, Wait for Get_next_Item()
            start_item(t);

            // ( randomize () with {constr} ) : Add to Constr
            if (!t.randomize()) begin
                `uvm_error("SEQ", "Randomization failed")
            end

            //Wait for Item_done()
            finish_item(t);
        end
    endtask

endclass
