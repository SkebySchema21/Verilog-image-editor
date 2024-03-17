`timescale 1ns / 1ps

module process(
  input clk, // clock
  input [23:0] in_pix, // valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
  output reg [5:0] row, col, // selecteaza un rand si o coloana din imagine
  output reg out_we, // activeaza scrierea pentru imaginea de iesire (write enable)
  output reg [23:0] out_pix, // valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
  output reg mirror_done, // semnaleaza terminarea actiunii de oglindire (activ pe 1)
  output reg gray_done, // semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
  output reg filter_done // semnaleaza terminarea actiunii de aplicare a filtrului de sharpness (activ pe 1)
);

// TODO add your finite state machines here;

// Definirea variabilelor
reg [5:0] state = 0, next_state = 0;
reg [5:0] in_row_mirror;
reg [7:0] gray_value;
reg [23:0] min_val, max_val;
reg [23:0] copy_1, copy_2;
reg [7:0] max_pix = 0, min_pix = 0;
reg freq1, freq2, freq3, freq4, freq5, freq6, freq7, freq8, freq9;
reg[23:0] sum1, sum2, sum_both;
reg[5:0] copy_row, copy_col;

// Definirea starilor
parameter S0 = 0;
parameter S1 = 1;
parameter S2 = 2;
parameter S3 = 3;
parameter S23 = 29;
parameter S4 = 4;
parameter S5 = 5;
parameter S6 = 6;
parameter S7 = 7;
parameter S8 = 8;
parameter S9 = 9;
parameter S10 = 10;
parameter S11 = 11;
parameter S12 = 12;
parameter S13 = 13;
parameter S14 = 14;
parameter S15 = 15;
parameter S_in_between = 28;
parameter Sanother = 27;
parameter Sceva = 26;
parameter Scoord = 25;

// Bloc always pentru schimbarea starilor
always @(posedge clk) begin
	state <= next_state;
end

// Bloc always pentru procesarea imaginii
always @(negedge clk) begin
	case(state)
		// Initializarea liniei si coloanei
		S0: begin
			row <= 0;
			col <= 0;
			mirror_done <= 0;
			gray_done <= 0;
			filter_done <= 0;
			next_state <= S1;
		end
		
		// In urmatorii pasi, cream doua copii ale pixelilor opusi, pentru a ii interschimba
		S1: begin
			out_we <= 0;
			copy_1 <= in_pix;
			next_state <= Sanother;
		end
		
		Sanother: begin
			row <= 63 - row;
			col <= col;
			next_state <= S2;
		end
		
		S2: begin
			out_we <= 1;
			copy_2 <= in_pix;
			out_pix <= copy_1;
			next_state <= S23;
		end
		
		S23: begin
		   row <= 63 - row;
			col <= col;
			out_pix <= copy_2;
			next_state <= S3;
		end
		
		// Incrementam pozitia pixelului, pana cand parcurgem jumatatea superioara a matricei. Pe urma, repetam toti pasii de oglindire, incepand cu S1
		S3: begin
		   out_we = 0;
			if(row == 31 && col == 63) begin
				mirror_done <= 1;
				next_state <= S4;
			end
			else if(col == 63) begin
				col <= 0;
				row <= row + 1;
				next_state <= S1;
			end
			else begin
				col <= col + 1;
				row <= row;
				next_state <= S1;
			end
		end
		
		//Initializam pozitia liniei si coloanei pentru grayscaling
		S4: begin
			row <= 0;
			col <= 0;
			next_state <= S5;
		end
		
		
		// Calculam atat componenta RGB maxima, cat si cea minima;
		S5: begin
			max_pix <= (in_pix[23:16] >= in_pix[15:8] ? in_pix[23:16] : in_pix[15:8]) >= (in_pix[23:16] >= in_pix[7:0] ? in_pix[23:16] : in_pix[7:0]) ? (in_pix[23:16] >= in_pix[15:8] ? in_pix[23:16] : in_pix[15:8]) : (in_pix[23:16] >= in_pix[7:0] ? in_pix[23:16] : in_pix[7:0]);
			min_pix <= (in_pix[23:16] <= in_pix[15:8] ? in_pix[23:16] : in_pix[15:8]) <= (in_pix[23:16] <= in_pix[7:0] ? in_pix[23:16] : in_pix[7:0]) ? (in_pix[23:16] <= in_pix[15:8] ? in_pix[23:16] : in_pix[15:8]) : (in_pix[23:16] <= in_pix[7:0] ? in_pix[23:16] : in_pix[7:0]);
			next_state <= S6;
		end
		
		// Scriem in pozitia G a pixelului media dintre componenta maxima si cea minima, restul devenind 0
		S6: begin
			out_we <= 1;
			out_pix[23:16] <= 0;
			out_pix[15:8] <= (max_pix + min_pix)/2;
			out_pix[7:0] <= 0;
			next_state <= Sceva;
		end
		
		// Incrementam pozitia pixelului, pana cand parcurgem intreaga matrice. Pe urma, repetam toti pasii de grayscale, incepand cu S5 
		Sceva: begin
			out_we <= 0;
			if(row == 63 && col == 63) begin
				gray_done <= 1;
				next_state <= S7;
			end
			else if(col == 63) begin
				col <= 0;
				row <= row + 1;
				next_state <= S5;
			end
			else begin
				col <= col + 1;
				row <= row;
				next_state <= S5;
			end
		end
		
		// Initializam pozitia liniei si coloanei pentru sharpening
		S7: begin
			row <= 0;
			col <= 0;
			next_state <= S8;
		end
		
		// Determinam care pixeli pot fi luati in considerare pentru inmultirea cu kernelul
		S8: begin
			sum1 <= 0;
			sum2 <= 0;
			sum_both <= 0;
			if(row == 0) begin
				freq1 <= 0;
				freq2 <= 0;
				freq3 <= 0;
				if(col == 0) begin
					freq1 <= 0;
					freq4 <= 0;
					freq7 <= 0;
					freq5 <= 1;
					freq6 <= 1;
					freq8 <= 1;
					freq9 <= 1;
					next_state <= S9;
				end
				else if(col == 63) begin
					freq3 <= 0;
					freq6 <= 0;
					freq9 <= 0;
					freq4 <= 1;
					freq2 <= 1;
					freq5 <= 1;
					freq7 <= 1;
					next_state <= S9;
				end
				else begin
					freq4 <= 1;
					freq7 <= 1;
					freq5 <= 1;
					freq6 <= 1;
					freq8 <= 1;
					freq9 <= 1;
					next_state <= S9;
				end
			end
			
			else if(row == 63) begin
				freq7 <= 0;
				freq8 <= 0;
				freq9 <= 0;
				if(col == 0) begin
					freq1 <= 0;
					freq4 <= 0;
					freq7 <= 0;
					freq2 <= 1;
					freq3 <= 1;
					freq5 <= 1;
					freq6 <= 1;
					next_state <= S9;
				end
				
				else if(col == 63) begin
					freq3 <= 0;
					freq6 <= 0;
					freq9 <= 0;
					freq1 <= 1;
					freq2 <= 1;
					freq4 <= 1;
					freq5 <= 1;
					next_state <= S9;
				end
				
				else begin
					freq1 <= 1;
					freq2 <= 1;
					freq3 <= 1;
					freq4 <= 1;
					freq5 <= 1;
					freq6 <= 1;
					next_state <= S9;
				end
			end
			
			else begin
				
				if(col == 0) begin
					freq1 <= 0;
					freq2 <= 1;
					freq3 <= 1;
					freq4 <= 0;
					freq5 <= 1;
					freq6 <= 1;
					freq7 <= 0;
					freq8 <= 1;
					freq9 <= 1;
					next_state <= S9;
				end
				
				else if(col == 63) begin
					freq1 <= 1;
					freq2 <= 1;
					freq3 <= 0;
					freq4 <= 1;
					freq5 <= 1;
					freq6 <= 0;
					freq7 <= 1;
					freq8 <= 1;
					freq9 <= 0;
					next_state <= S9;
				end
				
				else begin
					freq1 <= 1;
					freq2 <= 1;
					freq3 <= 1;
					freq4 <= 1;
					freq5 <= 1;
					freq6 <= 1;
					freq7 <= 1;
					freq8 <= 1;
					freq9 <= 1;
					next_state <= S9;
				end
			end
		end
		
		// Parcurgem toti "vecinii" pixelului, si ii adunam in doua sume, pe care le vom scadea ulterior pentru a afla valoarea finala aplicarii filtrului
		S9: begin
			if(freq1 > 0) begin
				copy_row <= row;
				copy_col <= col;
				row <= row - 1;
				col <= col - 1;
				freq1 <= 0;
				next_state <= S10;
			end
			
			else if(freq2 > 0) begin
				copy_row <= row;
				copy_col <= col;
				row <= row - 1;
				col <= col;
				freq2 <= 0;
				next_state <= S10;
			end
			
			else if(freq3 > 0) begin
				copy_row <= row;
				copy_col <= col;
				row <= row - 1;
				col <= col + 1;
				freq3 <= 0;
				next_state <= S10;
			end
			
			else if(freq4 > 0) begin
				copy_row <= row;
				copy_col <= col;
				row <= row;
				col <= col - 1;
				freq4 <= 0;
				next_state <= S10;
			end
			
			else if(freq5 > 0) begin
				sum1 = 9 * in_pix[15:8];
				freq5 <= 0;
				next_state <= S9;
			end
			
			else if(freq6 > 0) begin
				freq6 <= 0;
				copy_row <= row;
				copy_col <= col;
				row <= row;
				col <= col + 1;
				next_state <= S10;
			end
			
			else if(freq7 > 0) begin
				freq7 <= 0;
				copy_row <= row;
				copy_col <= col;
				row <= row + 1;
				col <= col - 1;
				next_state <= S10;
			end
			
			else if(freq8 > 0) begin
				freq8 <= 0;
				copy_row <= row;
				copy_col <= col;
				row <= row + 1;
				col <= col;
				next_state <= S10;
			end
			
			else if(freq9 > 0) begin
				freq9 <= 0;
				copy_row <= row;
				copy_col <= col;
				row <= row + 1;
				col <= col + 1;
				next_state <= S10;
			end
			
			else begin
				if(sum1 > sum2) begin
					sum_both = sum1 - sum2;
				end
				else begin
					sum_both = 0;
				end
				next_state <= S_in_between;
			end
		end
		
		// Convertirea sumei finale pe 8 biti, si plasarea ei pe canalul R
		S_in_between: begin
			out_we = 1;
			if(sum_both < 255) begin
				out_pix[23:16] <= sum_both;
			end
			else if(sum_both >= 255) begin
				out_pix[23:16] <= 255;
			end
			next_state <= S11;
		end
		
		// Calculul celei de-a doua sume
		S10: begin
			sum2 <= sum2 + in_pix[15:8];
			next_state <= Scoord;
		end
		
		// Resetarea coordonatelor
		Scoord: begin
			row <= copy_row;
			col <= copy_col;
			next_state <= S9;
		end
		
		// Incrementam pozitia pixelului, pana cand parcurgem intreaga matrice. Pe urma, repetam toti pasii de sharpness, incepand cu S8
		S11: begin
			out_we <= 0;
			if(row == 63 && col == 63) begin
				next_state <= S12;
			end
			else if(col == 63) begin
				col <= 0;
				row <= row + 1;
				next_state <= S8;
			end
			else begin
				col <= col + 1;
				row <= row;
				next_state <= S8;
			end
		end
		
		// Initializarea liniei si coloanei pentru mutarea rezultatului din canalul R in canalul G
		S12: begin
			row <= 0;
			col <= 0;
			next_state <= S13;
		end
		
		// Copierea valorii
		S13: begin
			out_pix[15:8] <= in_pix[23:16];
			out_we <= 1;
			next_state <= S14;
		end
		
		// Canalul R devine 0
		S14: begin
			out_pix[23:16] <= 0;
			out_pix[7:0] <= 0;
			next_state <= S15;
		end
		
		// Incrementam pozitia pixelului, pana cand parcurgem intreaga matrice.
		S15: begin
			out_we <= 0;
			if(row == 63 && col == 63) begin
				filter_done <= 1;
			end
			else if(col == 63) begin
				col <= 0;
				row <= row + 1;
				next_state <= S13;
			end
			else begin
				col <= col + 1;
				row <= row;
				next_state <= S13;
			end
		end
	endcase
end

endmodule
  