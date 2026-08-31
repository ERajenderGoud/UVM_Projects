module apb_slave #(
    parameter ADDR_WIDTH  = 8,
    parameter DATA_WIDTH  = 8,
    parameter WAIT_STATES = 2
)(
    input  wire                  PCLK,
    input  wire                  PRESETn,

    input  wire                  PSEL,
    input  wire                  PENABLE,
    input  wire                  PWRITE,
    input  wire [ADDR_WIDTH-1:0] PADDR,
    input  wire [DATA_WIDTH-1:0] PWDATA,

    output reg  [DATA_WIDTH-1:0] PRDATA,
    output reg                   PREADY,
    output reg                   PSLVERR
);
  
  localparam [ADDR_WIDTH-1:0] ADDR_CTRL    = 8'h00;
  localparam [ADDR_WIDTH-1:0] ADDR_STATUS  = 8'h04;
  localparam [ADDR_WIDTH-1:0] ADDR_DATA    = 8'h08;
  localparam [ADDR_WIDTH-1:0] ADDR_VERSION = 8'h0C;
  
  reg [DATA_WIDTH-1:0] ctrl_reg;
  reg [DATA_WIDTH-1:0] data_reg;
  reg [DATA_WIDTH-1:0] status_reg;
  
  reg [ADDR_WIDTH-1:0] addr_reg;
  reg                  write_reg;
  reg [DATA_WIDTH-1:0] wdata_reg;

  reg [7:0] wait_counter;
  
  localparam [1:0] IDLE = 2'b00, SETUP = 2'b01,ACCESS = 2'b10;
  
  reg [1:0] state;
  
  wire valid_addr;
  
  assign valid_addr = (addr_reg == ADDR_CTRL) || (addr_reg == ADDR_STATUS) || (addr_reg == ADDR_DATA) ||(addr_reg == ADDR_VERSION);
  
  
  always @(posedge PCLK or negedge PRESETn) begin
    
    if (!PRESETn) begin
      
      ctrl_reg   <= 8'h00;
      data_reg   <= 8'h00;
      status_reg <= 8'h00;
      
      addr_reg  <= 8'h00;
      write_reg <= 1'b0;
      wdata_reg <= 8'h00;
      
      PRDATA  <= 8'h00;
      PREADY  <= 1'b0;
      PSLVERR <= 1'b0;
      
      wait_counter <= 8'h00;
      
      state <= IDLE;
    
    end
    
    else begin
      
      PREADY  <= 1'b0;
      PSLVERR <= 1'b0;
      
      case (state)
        
        IDLE: begin
          
          wait_counter <= 8'h00;
          
          if(!PSEL && !PENABLE) begin
            state <= IDLE;
          end
          
          if (PSEL && !PENABLE) begin
            
            addr_reg  <= PADDR;
            write_reg <= PWRITE;
            wdata_reg <= PWDATA;
            
            state <= SETUP;
          end
        end
        
        SETUP: begin
          
          if (PSEL && PENABLE) begin
            
            wait_counter <= 8'h00;
            
            state <= ACCESS;
            
          end
          
          else if (!PSEL) begin
            state <= IDLE;
          end
        end
        
        ACCESS: begin
          
          if (PSEL && PENABLE) begin
            
            if (wait_counter < WAIT_STATES) begin
              
              wait_counter <= wait_counter + 1'b1;
              PREADY <= 1'b0;
            end
            
            else begin
              
              PREADY <= 1'b1;
              
              if (!valid_addr) begin
                
                PRDATA  <= 8'h00;
                PSLVERR <= 1'b1;
              end
              
              else if (write_reg) begin
                
                case (addr_reg)
                  
                  ADDR_CTRL: begin
                    ctrl_reg <= wdata_reg;
                  end
                  
                  ADDR_DATA: begin
                    
                    data_reg <= wdata_reg;
                  
                  end
                  
                  ADDR_STATUS: begin
                    
                    PSLVERR <= 1'b1;
                  
                  end
                  
                  ADDR_VERSION: begin
                    
                    PSLVERR <= 1'b1;
                  
                  end
                  
                  default: begin
                    
                    PSLVERR <= 1'b1;
                  
                  end
                endcase
              end
              
              else begin
                
                case (addr_reg)
                  
                  ADDR_CTRL: begin
                  
                  PRDATA <= ctrl_reg;
                
                end
                  ADDR_STATUS: begin
                    
                    PRDATA <= status_reg;
                  
                  end
                  
                  ADDR_DATA: begin
                    
                    PRDATA <= data_reg;
                  
                  end
                  
                  ADDR_VERSION: begin
                    
                    PRDATA <= 8'h01;
                  
                  end
                  
                  default: begin
                    PRDATA  <= 8'h00;
                    PSLVERR <= 1'b1;
                  end
                
                endcase
              
              end

              state <= IDLE;
            
            end
          end
          else begin

            state <= IDLE;

          end
        end
        default: begin
            state <= IDLE;
        end

        endcase

    end
  end
  
endmodule
