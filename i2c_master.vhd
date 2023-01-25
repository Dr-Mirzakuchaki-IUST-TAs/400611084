library ieee;
use ieee.std_logic_1164.all;

------------------------------------------------

entity i2c_master is

    port (

        clk         :   in      std_logic;
        reset_n     :   in      std_logic;                      -- active-low async reset
        ena         :   in      std_logic;                      -- enable
        addr        :   in      std_logic_vector (6 downto 0);  -- slave address
        rw          :   in      std_logic;                      -- read/write bit
        data_wr     :   in      std_logic_vector (7 downto 0);  -- data sending to slave
        
        data_rd     :   out     std_logic_vector (7 downto 0);  -- data received form slave
        busy        :   out     std_logic;
        ack_err     :   buffer  std_logic;
        
        scl         :   inout   std_logic;                      -- i2c protocol lines
        sda         :   inout   std_logic

    );

end i2c_master;

-------------------------------------------------

architecture behavioral of i2c_master is

    -- state machine
    type fsm is (idle, start, address, address_ack, write, read, slv_ack, mstr_ack, stop);
    signal state        :   fsm;

    -- internal signals
    signal data_clk     :   std_logic;
    signal data_clk_prv :   std_logic;
    signal scl_int      :   std_logic;
    signal scl_ena      :   std_logic   :=  '0';
    signal sda_int      :   std_logic   :=  '1';
    signal sda_ena_n    :   std_logic;

    -- internal signals to register inputs
    signal addr_rw_int  :   std_logic_vector (7 downto 0);
    signal data_wr_int  :   std_logic_vector (7 downto 0);
    signal data_rd_int  :   std_logic_vector (7 downto 0);

    -- bit counter
    signal bit_cnt      :   integer range 0 to 7    :=  7;          -- counting bits if tansfering frame of data or address

    -- constants
    constant cnt_limit  :   integer :=  500;                        -- clk input freq: 50 Mhz, i2c freq: 100 Khz

begin

    -- clocks generator
    process (clk, reset_n)

        variable count  :   integer range 0 to cnt_limit;

    begin

        if (reset_n = '0') then

            count := 0;

        elsif (clk'event and clk = '1') then

            data_clk_prv <= data_clk;

            if (count = cnt_limit - 1) then

                count := 0;

            else

                count := count + 1;

            end if;

            case count is                                       -- 90 degree phase difference between data_clk & scl_int

                when 0 to ((cnt_limit / 4) - 1)  =>

                    scl_int     <=  '0';
                    data_clk    <=  '0';

                when (cnt_limit / 4) to ((cnt_limit / 2) - 1)   =>

                    scl_int     <=  '0';
                    data_clk    <=  '1';

                when (cnt_limit / 2) to ((3 * cnt_limit / 4) - 1)   =>

                    scl_int     <=  '1';
                    data_clk    <=  '1';

                when others   =>

                    scl_int     <=  '1';
                    data_clk    <=  '0';

            end case;

        end if;

    end process;

    ------------------------------------

    -- state machine
    process (clk, reset_n)

    begin

        if (reset_n = '0') then

            state   <=  idle;
            busy    <=  '1';
            scl_ena <=  '0';                                        -- scl line becomes high z
            sda_int <=  '1';                                        -- sda line becomes high z
            ack_err <=  '0';
            bit_cnt <=  7;                                          -- reset bit counter, data transfers from MSB to LSB (bit 7 to bit 0)
            data_rd  <=  (others => '0');

        elsif (clk'event and clk = '1') then

            if (data_clk_prv = '0' and data_clk = '1') then         -- data_clk rising edge

                case state is

                    when idle =>

                        if (ena = '1') then

                            busy        <=  '1';
                            addr_rw_int <=  addr & rw;              -- sampling from inputs: address, rw & data_wr
                            data_wr_int <=  data_wr;
                            state       <=  start;

                        else

                            busy    <=  '0';
                            state   <=  idle;

                        end if;

                    when start  =>

                        busy    <= '1';
                        sda_int <=  addr_rw_int (bit_cnt);
                        state   <=  address;

                    when address =>

                        if (bit_cnt = 0) then

                            sda_int <=  '1';
                            bit_cnt <=  7;
                            state   <=  address_ack;

                        else

                            bit_cnt <=  bit_cnt - 1;
                            sda_int <=  addr_rw_int (bit_cnt - 1);
                            state   <=  address;

                        end if;

                    when address_ack    =>

                        if (addr_rw_int (0) = '0') then

                            sda_int <=  data_wr_int (bit_cnt);
                            state   <=  write;

                        else

                            sda_int <=  '1';
                            state   <=  read;

                        end if;

                    when write  =>

                        busy    <=  '1';

                        if (bit_cnt = 0) then

                            sda_int <=  '1';
                            bit_cnt <=  7;
                            state   <=  slv_ack;

                        else

                            bit_cnt <=  bit_cnt - 1;
                            sda_int <=  data_wr_int (bit_cnt - 1);
                            state   <=  write;
                        
                        end if;

                    when slv_ack    =>

                        if (ena = '1') then

                            busy        <=  '0';
                            addr_rw_int <=  addr & rw;
                            data_wr_int <=  data_wr;

                            if (addr_rw_int = addr & rw) then

                                sda_int <=  data_wr_int (bit_cnt);
                                state   <=  write;

                            else

                                state   <=  start;

                            end if;

                        else

                            state   <=  stop;

                        end if;

                    when read   =>

                        busy    <=  '1';

                        if (bit_cnt = 0) then

                            if (ena = '1' and addr_rw_int = addr & rw) then

                                sda_int <=  '0';                        -- ack if there are more data to receive

                            else

                                sda_int <=  '1';                        -- else nack

                            end if;

                            bit_cnt <=  7;
                            data_rd <=  data_rd_int;
                            state   <=  mstr_ack;

                        else

                            bit_cnt <=  bit_cnt - 1;
                            state   <=  read;

                        end if;

                    when mstr_ack   =>

                        if (ena = '1') then

                            busy        <=  '0';
                            addr_rw_int <=  addr & rw;
                            data_wr_int <=  data_wr;

                            if (addr_rw_int = addr & rw) then

                                sda_int <= '1';
                                state   <=  read;

                            else

                                state   <=  start;

                            end if;

                        else

                            state   <= stop;

                        end if;

                    when stop   =>

                        busy    <=  '0';
                        state   <= idle;

                end case;

             -----------------------------------

            elsif (data_clk_prv = '1' and data_clk = '0') then          -- data_clk falling edge

                case state is

                    when start  =>

                        if (scl_ena = '0') then

                            scl_ena <=  '1';                            -- enables scl oscillating for start state
                            ack_err <=  '0';
                        
                        end if;

                    when address_ack    =>

                        if (sda /=  '0' or ack_err = '1') then          -- nack or prior ack error

                            ack_err <=  '1';

                        end if;

                    when read   =>

                        data_rd_int (bit_cnt)   <=  sda;

                    when slv_ack    =>

                        if (sda /= '0' or ack_err = '1') then           -- nack or prior ack error

                            ack_err <=  '1';

                        end if;

                    when stop   =>

                        scl_ena <= '0';                                 -- disables scl oscillating for stop state

                    when others =>

                        null;

                end case;

            end if;

        end if;
    
    end process;

    -------------------------------------------

    -- i2c protocol lines assignment
    with state select

        sda_ena_n   <=  data_clk_prv        when    start,              -- start condition, negative edge of sda
                        not data_clk_prv    when    stop,               -- stop condition,  positive edge of sda
                        sda_int             when    others;

    -- lines are open drain
    scl <=  '0' when    (scl_ena    = '1' and scl_int = '0')    else   'Z';
    sda <=  '0' when    sda_ena_n   = '0' else  'Z';

end behavioral;