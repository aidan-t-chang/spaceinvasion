`include "hvsync_generator.v"
`include "lfsr.v"
`include "sprite_bitmap.v"
`include "sprite_renderer.v"

module top(clk, reset, hsync, vsync, rgb, keycode, keystrobe, left_out, right_out, up_out, down_out);

  input clk, reset;
  input [7:0] keycode;
  input keystrobe;
  output hsync, vsync;
  output reg left_out = 0;
  output reg right_out = 0;
  output reg up_out = 0;
  output reg down_out = 0;
  output [2:0] rgb;
  wire display_on;
  wire [8:0] hpos;
  wire [8:0] vpos;
  wire [15:0] lfsr;  
  wire player_gfx;
  wire player_is_drawing;

  // asteroids position and active flags
  reg [7:0] asteroid_x [0:3];
  reg [7:0] asteroid_y [0:3];
  reg asteroid_active [0:3];
  
  wire [3:0] player_sprite_yofs;
  wire [3:0] asteroid_sprite_yofs [0:3];
  
  reg [1:0] current_asteroid = 0;
  wire [3:0] car_sprite_yofs = player_load ? player_sprite_yofs : asteroid_sprite_yofs[current_asteroid];  
  wire [7:0] car_sprite_bits;      
  
  car_bitmap car(
    .yofs(car_sprite_yofs), 
    .bits(car_sprite_bits));

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );
  
  sprite_renderer player_renderer(
    .clk(clk),
    .vstart(player_vstart),
    .load(player_load),
    .hstart(player_hstart),
    .rom_addr(player_sprite_yofs),
    .rom_bits(car_sprite_bits),
    .gfx(player_gfx),
    .in_progress(player_is_drawing));
  
  wire [3:0] asteroid_gfx;
  wire [3:0] asteroid_is_drawing;
  
  sprite_renderer asteroid_renderer0(
    .clk(clk),
    .vstart(asteroid_vstart[0]),
    .load(asteroid_load[0]),
    .hstart(asteroid_hstart[0]),
    .rom_addr(asteroid_sprite_yofs[0]),
    .rom_bits(car_sprite_bits),
    .gfx(asteroid_gfx[0]),
    .in_progress(asteroid_is_drawing[0]));
    
  sprite_renderer asteroid_renderer1(
    .clk(clk),
    .vstart(asteroid_vstart[1]),
    .load(asteroid_load[1]),
    .hstart(asteroid_hstart[1]),
    .rom_addr(asteroid_sprite_yofs[1]),
    .rom_bits(car_sprite_bits),
    .gfx(asteroid_gfx[1]),
    .in_progress(asteroid_is_drawing[1]));
    
  sprite_renderer asteroid_renderer2(
    .clk(clk),
    .vstart(asteroid_vstart[2]),
    .load(asteroid_load[2]),
    .hstart(asteroid_hstart[2]),
    .rom_addr(asteroid_sprite_yofs[2]),
    .rom_bits(car_sprite_bits),
    .gfx(asteroid_gfx[2]),
    .in_progress(asteroid_is_drawing[2]));
    
  sprite_renderer asteroid_renderer3(
    .clk(clk),
    .vstart(asteroid_vstart[3]),
    .load(asteroid_load[3]),
    .hstart(asteroid_hstart[3]),
    .rom_addr(asteroid_sprite_yofs[3]),
    .rom_bits(car_sprite_bits),
    .gfx(asteroid_gfx[3]),
    .in_progress(asteroid_is_drawing[3]));
  
  wire star_enable = !hpos[8] & !vpos[8];
  
  LFSR #(16'b1000000001011,0) lfsr_gen(
    .clk(clk),
    .reset(reset),
    .enable(star_enable),
    .lfsr(lfsr));
  
  reg [7:0] player_x;
  reg [7:0] player_y;  
  
  // counter against multiple inputs for clock per keystrobe
  reg [15:0] key_debounce = 0;
  reg [7:0] last_keycode = 0;
  
  reg [15:0] asteroid_move_counter = 0;
  reg [19:0] spawn_counter = 0;
  reg [1:0] next_asteroid_to_spawn = 0;

  wire player_load = (hpos >= 256) && (hpos < 260);
  wire [3:0] asteroid_load;
  
  assign asteroid_load[0] = (hpos >= 260) && (hpos < 264);
  assign asteroid_load[1] = (hpos >= 264) && (hpos < 268);
  assign asteroid_load[2] = (hpos >= 268) && (hpos < 272);
  assign asteroid_load[3] = (hpos >= 272) && (hpos < 276);
  
  wire player_vstart = {1'b0, player_y} == vpos;
  wire player_hstart = {1'b0, player_x} == hpos;
  
  wire [3:0] asteroid_vstart;
  wire [3:0] asteroid_hstart;
  
  assign asteroid_vstart[0] = asteroid_active[0] && ({1'b0, asteroid_y[0]} == vpos);
  assign asteroid_hstart[0] = asteroid_active[0] && ({1'b0, asteroid_x[0]} == hpos);
  
  assign asteroid_vstart[1] = asteroid_active[1] && ({1'b0, asteroid_y[1]} == vpos);
  assign asteroid_hstart[1] = asteroid_active[1] && ({1'b0, asteroid_x[1]} == hpos);
  
  assign asteroid_vstart[2] = asteroid_active[2] && ({1'b0, asteroid_y[2]} == vpos);
  assign asteroid_hstart[2] = asteroid_active[2] && ({1'b0, asteroid_x[2]} == hpos);
  
  assign asteroid_vstart[3] = asteroid_active[3] && ({1'b0, asteroid_y[3]} == vpos);
  assign asteroid_hstart[3] = asteroid_active[3] && ({1'b0, asteroid_x[3]} == hpos);
  
  wire player_pixel_on = display_on && player_gfx;
  wire asteroid_pixel_on = display_on && (asteroid_gfx[0] || asteroid_gfx[1] || asteroid_gfx[2] || asteroid_gfx[3]);
  wire star_on = &lfsr[14:6];
  
  // draw the player -> draw the asteroid -> draw the display
  assign rgb = player_pixel_on ? 3'b111 : 
               (asteroid_pixel_on ? 3'b110 : 
               (display_on && star_on ? 3'b111 : 3'b000));

  always @(posedge clk) begin
    if (asteroid_load[0]) current_asteroid <= 2'd0;
    else if (asteroid_load[1]) current_asteroid <= 2'd1;
    else if (asteroid_load[2]) current_asteroid <= 2'd2;
    else if (asteroid_load[3]) current_asteroid <= 2'd3;
  end

  always @(posedge clk) begin
    if (reset) begin
      player_x <= 8'd100;
      player_y <= 8'd100;
      key_debounce <= 0;
      last_keycode <= 0;
    end else begin
      if (key_debounce > 0)
        key_debounce <= key_debounce - 1;
      
      if (keystrobe && key_debounce == 0) begin
        case (keycode)
          8'h27: begin
            if (player_x < 8'd240) begin
              player_x <= player_x + 8'd3;
              key_debounce <= 16'd20000;
              last_keycode <= keycode;
            end
          end
          8'h25: begin
            if (player_x > 8'd3) begin
              player_x <= player_x - 8'd3;
              key_debounce <= 16'd20000;
              last_keycode <= keycode;
            end
          end
          8'h26: begin
            if (player_y > 8'd3) begin
              player_y <= player_y - 8'd3;
              key_debounce <= 16'd20000;
              last_keycode <= keycode;
            end
          end
          8'h28: begin
            if (player_y < 8'd220) begin
              player_y <= player_y + 8'd3;
              key_debounce <= 16'd20000;
              last_keycode <= keycode;
            end
          end
          default: begin
          end
        endcase
      end
    end
  end
  
  // asteroid spawns
  always @(posedge clk) begin
    if (reset) begin
      asteroid_x[0] <= 8'd0;
      asteroid_y[0] <= 8'd0;
      asteroid_active[0] <= 0;
      asteroid_x[1] <= 8'd0;
      asteroid_y[1] <= 8'd0;
      asteroid_active[1] <= 0;
      asteroid_x[2] <= 8'd0;
      asteroid_y[2] <= 8'd0;
      asteroid_active[2] <= 0;
      asteroid_x[3] <= 8'd0;
      asteroid_y[3] <= 8'd0;
      asteroid_active[3] <= 0;
      asteroid_move_counter <= 0;
      spawn_counter <= 0;
      next_asteroid_to_spawn <= 0;
    end else begin
      // counters
      asteroid_move_counter <= asteroid_move_counter + 1;
      spawn_counter <= spawn_counter + 1;
      
      if (asteroid_move_counter == 16'd65535) begin
        if (asteroid_active[0]) begin
          if (asteroid_x[0] > 8'd1)
            asteroid_x[0] <= asteroid_x[0] - 8'd1;
          else
            asteroid_active[0] <= 0; // deactivate when off screen
        end
        
        if (asteroid_active[1]) begin
          if (asteroid_x[1] > 8'd1)
            asteroid_x[1] <= asteroid_x[1] - 8'd1;
          else
            asteroid_active[1] <= 0;
        end
        
        if (asteroid_active[2]) begin
          if (asteroid_x[2] > 8'd1)
            asteroid_x[2] <= asteroid_x[2] - 8'd1;
          else
            asteroid_active[2] <= 0;
        end
        
        if (asteroid_active[3]) begin
          if (asteroid_x[3] > 8'd1)
            asteroid_x[3] <= asteroid_x[3] - 8'd1;
          else
            asteroid_active[3] <= 0;
        end
      end
      
      if (spawn_counter == 20'd500000) begin // change how fast asteroids spawn
        spawn_counter <= 0;
        
        if (!asteroid_active[next_asteroid_to_spawn]) begin
          asteroid_x[next_asteroid_to_spawn] <= 8'd240;
          asteroid_y[next_asteroid_to_spawn] <= lfsr[7:0]; // random y position from lfsr
          asteroid_active[next_asteroid_to_spawn] <= 1;
        end
        next_asteroid_to_spawn <= next_asteroid_to_spawn + 1;
      end
    end
  end

endmodule